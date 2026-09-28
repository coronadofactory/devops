#!/bin/sh

##
## Devops Docker
## 
## Copyright (c) 1984-2026 Jose Garcia
## Released under the MIT license
## https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
## 
## Description: Script universal para Docker 
## Date: 2026-09-28
## 




# Asegurar que el script se ejecuta como root (adaptado a sh)

if [ "$(id -u)" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o usando sudo."
  exit 1
elif [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "❌ No se pudo identificar el sistema operativo."
    exit 1
fi

if [ ! -f ./docker.properties ]; then
    echo "docker.properties not found"
    exit 1
fi

case "$1" in
    run|mongosh|certs|remove)
        CMD=$1
        ;;
    *)
        echo "Invalid command: $1" >&2
        exit 1
        ;;
esac

# Extricto para produccióm
set -eu

MONGO_VERSION=`cat docker.properties | grep "mongodb=" | cut -d'=' -f2`
MONGO_DATA_DIR=`cat docker.properties | grep "mongodir=" | cut -d'=' -f2`
NGINX_HTML_FOLDER=`cat docker.properties | grep "nginxhtml=" | cut -d'=' -f2`
NGINX_CERTS_DIR=`cat docker.properties | grep "nginxcerts=" | cut -d'=' -f2`
EXPRESS_FOLDER=`cat docker.properties | grep "expressfolder=" | cut -d'=' -f2`



if [ -n "${MONGO_VERSION:-}" ]; then
    if [ -z "${MONGO_DATA_DIR:-}" ]; then
        echo "No mongodir not defined"
        exit
    fi
fi

if [ -n "${NGINX_HTML_FOLDER:-}" ] || [ -n "${NGINX_CERTS_DIR:-}" ]; then
    if [ -z "${NGINX_HTML_FOLDER:-}" ]; then
        echo "No nginghtml not defined"
        exit
    elif [ -z "${NGINX_CERTS_DIR:-}" ]; then
        echo "No nginxcerts not defined"
        exit
    fi
fi

NETWORK_NAME="app-net"


# Install docker

if [ "$CMD" = "run" ] && ! command -v docker >/dev/null 2>&1; then

echo "Iniciando instalación de Docker para: $NAME ($VERSION_ID)"


# Lógica de instalación según el SO
case "$ID" in
    amzn)
        if [ "$VERSION_ID" = "2023" ]; then
            echo "Usando DNF para Amazon Linux 2023..."
            dnf update -y
            dnf install -y docker
            sudo systemctl start docker
            sudo systemctl status docker
            usermod -aG docker ec2-user
            
        elif [ "$VERSION_ID" = "2" ]; then
#           sudo sed -i '/timeout=60/d' /etc/yum.conf
#           sudo sed -i '/retries=5/d' /etc/yum.conf

            # 1. Eliminar repositorios problemáticos (tanto el de Docker para CentOS como los de MySQL)
            sudo rm -f /etc/yum.repos.d/docker-ce.repo
            sudo rm -f /etc/yum.repos.d/mysql*.repo

            # 2. Limpiar la caché del gestor de paquetes
            sudo yum clean all

            # 3. Instalar Docker usando el paquete nativo oficial de Amazon Linux 2
            sudo amazon-linux-extras install docker -y

            sudo systemctl start docker
            sudo systemctl status docker
#            usermod -aG docker ec2-user

        else
            echo "❌ Versión de Amazon Linux ($VERSION_ID) no soportada por este script."
            exit 1
        fi
        ;;
        
    ubuntu|debian)
        echo "Usando el script oficial de Docker para $NAME..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        
        sudo systemctl start docker
        sudo systemctl status docker
        
        # Redirección POSIX para comprobar si existe el usuario ubuntu
        if id "ubuntu" >/dev/null 2>&1; then
            usermod -aG docker ubuntu
        fi
        ;;

        # Para eliminarlo 
        # sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras
        # sudo apt-get autoremove -y --purge
        # sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker

    rhel|centos|rocky|almalinux)
        echo "Usando el script oficial de Docker para $NAME..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        
        sudo systemctl start docker
        sudo systemctl status docker
        
        if id "ec2-user" >/dev/null 2>&1; then
            usermod -aG docker ec2-user
        fi
        ;;
        
    *)
        echo "❌ Sistema operativo no soportado: $ID"
        exit 1
        ;;
esac

echo "✅ Instalación completada. Cierra sesión y vuelve a entrar para aplicar los permisos de grupo."



# Docker install  
fi



# Comprobar si Docker ya está ejecutándose

if [ "$CMD" = "run" ] && ! systemctl is-active --quiet docker; then
    echo "⚠️ Docker no está corriendo. Intentando arrancarlo..."
    sudo systemctl start docker
    sudo systemctl status docker
    
    # Verificar si el arranque tuvo éxito
    if systemctl is-active --quiet docker; then
        echo "✅ Docker se ha arrancado correctamente."
    else
        echo "❌ Error: No se pudo arrancar Docker."
        exit 1
    fi
fi



# Crea la red de docker

if [ "$CMD" = "run" ] && ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "🌐 Creando red Docker externa: $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
fi



container_dir() {

    DIR="$1"

    if [ -z "$DIR" ]; then
        echo "❌ Error: Debes indicar el nombre del contenedor." >&2
        return 1
    fi

    echo "📁 Creando directorio persistente volumen externo: $DIR"

}

container_start() {
    
    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Error: Debes indicar el nombre del contenedor." >&2
        return 1
    fi

    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then
        echo "❌ Error crítico: El contenedor '${CONTAINER_NAME}' no existe." >&2
    elif [ "$STATUS" = "false" ]; then
        echo "🚀 Arrancando ${CONTAINER_NAME}..."
        docker start "${CONTAINER_NAME}"
        sleep 2
        FINAL_CHECK=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
        if [ "$FINAL_CHECK" = "true" ]; then
            echo "✅ '$CONTAINER_NAME' se ha iniciado con exito."
        else
            echo "❌ Error crítico: El contenedor '$CONTAINER_NAME' falló al arrancar." >&2
            echo "--- Logs de "$CONTAINER_NAME" ---" >&2
            docker logs --tail 20 "$CONTAINER_NAME" >&2
            exit 1
        fi
    else
        echo "ℹ️ El contenedor '${CONTAINER_NAME}' ya está en ejecución."
    fi

}

container_check() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Error: Debes indicar el nombre del contenedor." >&2
        return 1
    fi

    sleep 2

    FINAL_CHECK=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
    if [ "$FINAL_CHECK" = "true" ]; then
        echo "✅ '$CONTAINER_NAME' se ha iniciado con exito."
    else
        echo "❌ Error crítico: El contenedor '$CONTAINER_NAME' falló al arrancar." >&2
        echo "--- Logs de '$CONTAINER_NAME' ---" >&2
        docker logs --tail 20 "$CONTAINER_NAME" >&2
        exit 1
    fi
 
}

container_ok_message() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Error: Debes indicar el nombre del contenedor." >&2
        return 1
    fi

    echo "ℹ️ El contenedor '${CONTAINER_NAME}' ya está en ejecución."

}

container_run_message() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Error: Debes indicar el nombre del contenedor." >&2
        return 1
    fi

    echo "🚀 Creando e iniciando el contenedor '${CONTAINER_NAME}'..."
}

container_build_message() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Error: Debes indicar el nombre del contenedor." >&2
        return 1
    fi

    echo "🔄 Construyendo la imagen '${EXPRESS_IMAGE_NAME}'..."

}

#  MongoDB

if [ "$CMD" = "run" ] && [ -n "${MONGO_VERSION:-}" ]; then

    CONTAINER_NAME="mongodb"
    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then
        if [ ! -d "$MONGO_DATA_DIR" ]; then
            container_dir "${MONGO_DATA_DIR}"
            mkdir -p "$MONGO_DATA_DIR"
            # Ajustar permisos si es necesario para evitar problemas de acceso del motor de Mongo
            chmod 755 "$MONGO_DATA_DIR"
        fi

        container_run_message "${CONTAINER_NAME}"
        docker run -d \
            --name "$CONTAINER_NAME" \
            --network "$NETWORK_NAME" \
            --restart unless-stopped \
            -p 27017:27017 \
            -v "$MONGO_DATA_DIR:/data/db" \
        mongo:$MONGO_VERSION

        container_check "${CONTAINER_NAME}"
            
    elif [ "$STATUS" = "false" ]; then
        container_start "${CONTAINER_NAME}"

    else
        container_ok_message "${CONTAINER_NAME}"

    fi

    # docker exec -it mongodb mongosh -u admin -p secretpassword --authenticationDatabase admin
fi



# Nginx

if [ "$CMD" = "run" ] && [ -n "${NGINX_HTML_FOLDER:-}" ]; then

    CONTAINER_NAME="nginx"
    NGINX_HTML_IMAGE_NAME="document-root"

    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then
        if [ -n "${NGINX_HTML_FOLDER:-}" ]; then

            container_build_message "${CONTAINER_NAME}"
            docker build -t "${NGINX_HTML_IMAGE_NAME}" "${NGINX_HTML_FOLDER}"

            container_run_message "${CONTAINER_NAME}"
            docker run -d \
                --name "$CONTAINER_NAME" \
                --network "$NETWORK_NAME" \
                --restart unless-stopped \
                -p 80:80 \
                -p 443:443 \
                -v "$NGINX_CERTS_DIR:/etc/nginx/certs:ro" \
                "${NGINX_HTML_IMAGE_NAME}"

            container_check "${CONTAINER_NAME}"

        fi
            
    elif [ "$STATUS" = "false" ]; then
        container_start "${CONTAINER_NAME}"

    else
        container_ok_message "${CONTAINER_NAME}"

    fi


    # echo "🛑 Deteniendo y limpiando el contenedor "$NGINX_CONTAINER_NAME" ..."
    # docker stop "$NGINX_CONTAINER_NAME" 2>/dev/null || true
    # docker rm "$NGINX_CONTAINER_NAME" 2>/dev/null || true

fi



# ExpressJS

if [ "$CMD" = "run" ] && [ -n "${EXPRESS_FOLDER:-}" ]; then

    CONTAINER_NAME="express"
    EXPRESS_IMAGE_NAME="express-app"

    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then

        container_build_message "${CONTAINER_NAME}"
        docker build -t "${EXPRESS_IMAGE_NAME}" "${EXPRESS_FOLDER}"

        container_run_message "${CONTAINER_NAME}"
        docker run -d \
            --name "${CONTAINER_NAME}" \
            --network "$NETWORK_NAME" \
            "${EXPRESS_IMAGE_NAME}"

        container_check "${CONTAINER_NAME}"

    elif [ "$STATUS" = "false" ]; then
        container_start "${CONTAINER_NAME}"

    else
        container_ok_message "${CONTAINER_NAME}"

    fi

    # echo "Limpiando contenedor previo si existe..."
    # docker stop "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true
    # docker rm "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true


fi



if [ "$CMD" = "remove" ]; then

docker stop $(docker ps -q) 2>/dev/null
docker container prune -f

case "$ID" in
    amzn)
        if [ "$VERSION_ID" = "2023" ]; then
            echo "Para eliminarlo teclee"
            echo ""
            echo "sudo dnf remove -y docker docker-ce docker-ce-cli containerd.io docker-compose-plugin"
            echo "sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker"
            
        elif [ "$VERSION_ID" = "2" ]; then
            echo "Para eliminarlo teclee"
            echo ""
            echo "sudo yum remove -y docker"
            echo "sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker"

        else
            echo "❌ Versión de Amazon Linux ($VERSION_ID) no soportada por este script."
            exit 1
        fi
        ;;
        
    ubuntu|debian)
        echo "Para eliminarlo teclee"
        echo ""
        echo "sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras"
        echo "sudo apt-get autoremove -y --purge"
        echo "sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker"
        ;;

    rhel|centos|rocky|almalinux)
        echo "No hay script"
        ;;
        
    *)
        echo "❌ Sistema operativo no soportado: $ID"
        exit 1
        ;;
esac

fi



if [ "$CMD" = "mongosh" ]; then
    docker exec -it mongodb mongosh
fi



if [ "$CMD" = "certs" ]; then
    docker exec nginx nginx -s reload
fi
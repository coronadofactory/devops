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
## Rev: 2026-10-04


# Verificar si el usuario tiene privilegios sudo o es root
if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    TARGET_USER="root"
else
    TARGET_USER="${SUDO_USER:-$USER}"
fi

if [ "$TARGET_USER" = "root" ]; then
    echo ""
    echo " ✅ Permisos de sudo verificados. Es usuario $TARGET_USER."
elif ! sudo -v >/dev/null 2>&1; then
    echo ""
    echo " ❌ ERROR: El usuario '$USER' no tiene permisos de sudo o la clave es incorrecta."
    exit 1
else
    echo " ✅ Permisos de sudo verificados para usuario $TARGET_USER."
fi



if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo ""
    echo " ❌ No se pudo identificar el sistema operativo."
    exit 1
fi

case "$1" in
    run|mongosh|remove)
        CMD=$1
        ;;
    upgrade)
        CMD=$1
        case "$2" in
            expressjs)
                CMD=$1
                ;;
            mongodb)
                MODULE=$2
                if [ "$2" = "mongodb" ]; then
                    if [ -n "$3" ]; then
                        MONGO_JSON_FILE="$3"
                    else
                        echo "Mongo file not defined to update."
                        exit 1
                    fi 
                fi
                ;;
            "")
                echo "Nothing to upgrade?"
                exit 1
                ;;
            *)
                echo "Invalid module: $2"
                exit 1
                ;;
        esac
        ;;
    renove)
        if [ "$2" = "cerbot"]; then
            CMD="$2"
        else 
            echo "Invalid app: $APP. Expected cerbot."
            exit 1
        fi
        ;;
    "")
        echo "Parameters?"
        exit 1
        ;;
    *)
        echo "Invalid command: $1"
        exit 1
        ;;
esac

# Extricto para produccióm
set -eu

PROPERTIES="cf.docker.properties"
if [ ! -f ./$PROPERTIES ]; then
    echo ""
    echo "$PROPERTIES not found"
    exit 1
fi

MONGO_VERSION=`cat $PROPERTIES | grep "mongodb.version=" | cut -d'=' -f2`
MONGO_DATA_DIR=`cat $PROPERTIES | grep "mongodb.dir=" | cut -d'=' -f2`
MONGO_COLLECTIONS_DIR=`cat $PROPERTIES | grep "mongodb.data=" | cut -d'=' -f2`
NGINX_HTML_FOLDER=`cat $PROPERTIES | grep "nginx.documents.folder=" | cut -d'=' -f2`
EXPRESS_FOLDER=`cat $PROPERTIES | grep "expressjs.app.folder=" | cut -d'=' -f2`
CERTBOT_DOMAIN=`cat $PROPERTIES | grep "cerbot.domain=" | cut -d'=' -f2`
CERTBOT_EMAIL=`cat $PROPERTIES | grep "cerbot.email=" | cut -d'=' -f2`

NETWORK_NAME="app-net"
NGINX_CERTS_DIR="/etc/nginx/certs"

# Sincroniza nginx y certbot
CERTBOT_VALIDATOR_DIR="/var/www/certbot"
CERTBOT_VALIDATOR_PATH="/var/www/certbot"

if [ -n "${MONGO_VERSION:-}" ]; then
    if [ -z "${MONGO_DATA_DIR:-}" ]; then
        echo " ❌ No mongodb.dir not defined"
        exit
    fi
fi

# Comprueba que existe el folder HTML
if [ -n "${NGINX_HTML_FOLDER:-}" ]; then
    if [ ! -d "${NGINX_HTML_FOLDER}" ]; then
        echo ""
        echo " ❌ ${NGINX_HTML_FOLDER} folder not found"
        exit 1
    elif [ ! -f "${NGINX_HTML_FOLDER}/Dockerfile" ]; then
        echo ""
        echo " ❌ ${NGINX_HTML_FOLDER}/Dockerfile not found"
        exit 1
    fi
fi

# Configuracion necesario de Certbot si se llama en el arranque
if [ "$CMD" = "run" ]; then
    if [ -z "${CERTBOT_DOMAIN:-}" ] && [ -n "${CERTBOT_EMAIL:-}" ]; then
        echo ""
        echo " ❌ cerbot.domain not defined for cerbot process"
        exit 1
    elif [ -n "${CERTBOT_DOMAIN:-}" ] && [ -z "${CERTBOT_EMAIL:-}" ]; then
        echo ""
        echo " ❌ No cerbot.email not defined for cerbot process"
        exit 1
    fi
fi

# Configuracion necesaria de Certbot si se va renovar certificados
if [ "$CMD" = "certbot" ]; then
    if [ -z "${CERTBOT_DOMAIN:-}" ]; then
        echo ""
        echo " ❌ cerbot.domain not defined for cerbot process"
        exit 1
    elif [ -z "${CERTBOT_EMAIL:-}" ]; then
        echo ""
        echo " ❌ No cerbot.email not defined for cerbot process"
        exit 1
    fi
fi



# Install docker

if [ "$CMD" = "run" ] && ! command -v docker >/dev/null 2>&1; then

echo "Iniciando instalación de Docker para: $NAME ($VERSION_ID)"

# I1. Lógica de instalación según el SO
case "$ID" in
    amzn)
        if [ "$VERSION_ID" = "2023" ]; then
            echo "Usando DNF para Amazon Linux 2023..."
            dnf update -y
            dnf install -y docker
            
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

        else
            echo ""
            echo " ❌ Versión de Amazon Linux ($VERSION_ID) no soportada por este script."
            exit 1
        fi
        ;;
        
    ubuntu|debian|rhel|centos|rocky|almalinux)
        echo "Usando el script oficial de Docker para $NAME..."
        curl -fsSL https://get.docker.com | sh
        ;;
        
    *)
        echo ""
        echo " ❌ Sistema operativo no soportado: $ID"
        exit 1
        ;;
esac

# I2. Asignando el usuario al grupo docker
if [ "$TARGET_USER" != "root" ] && id "$TARGET_USER" >/dev/null 2>&1; then
    if ! id -nG "$USER" | grep -qw "docker"; then
        sudo usermod -aG docker "$TARGET_USER"
        echo ""
        echo " ⚠️  IMPORTANTE: Se han actualizado los permisos de usuario."
        echo " 🔄 Para que la sesión reconozca el grupo 'docker', por favor:"
        echo "   1. Escribe 'exit' (o cierra la sesión SSH)."
        echo "   2. Vuelve a conectarte al servidor."
        echo "   3. Vuelve a ejecutar este script."
        echo ""
        exit 0
    fi
fi

# I3. Iniciamos docker por primera vez
sudo systemctl start docker
sudo systemctl status docker

# Docker install  
fi



# Comprueba que el usuario se asignó al grupo docker en la instalación 
if [ "$TARGET_USER" != "root" ] && ! id -nG "$USER" | grep -qw "docker"; then
    echo ""
    echo " ❌ El usuario $TARGET_USER no está asignado al grupo docker"
    exit 1
fi



# Comprobar si Docker ya está ejecutándose

if [ "$CMD" = "run" ] && ! systemctl is-active --quiet docker; then
    echo ""
    echo " ⚠️ Docker no está corriendo. Intentando arrancarlo..."
    sudo systemctl start docker
    sudo systemctl status docker
    
    # Verificar si el arranque tuvo éxito
    if systemctl is-active --quiet docker; then
        echo " ✅ Docker se ha arrancado correctamente."
    else
        echo " ❌ Error: No se pudo arrancar Docker."
        exit 1
    fi
else 
    echo ""
    echo " ✅ Docker está corriendo."
fi



# Crea la red de docker

if [ "$CMD" = "run" ] && ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo ""
    echo " 🌐 Creando red Docker externa: $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
fi



container_dir() {

    DIR="$1"

    if [ -z "$DIR" ]; then
        echo ""
        echo " ❌ Error: Debes indicar el nombre del contenedor."
        return 1
    fi

    echo ""
    echo " 📁 Creando directorio persistente volumen externo: $DIR"

}

container_start() {
    
    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo ""
        echo " ❌ Error: Debes indicar el nombre del contenedor."
        echo ""
        return 1
    fi

    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then
        echo ""
        echo " ❌ Error crítico: El contenedor '${CONTAINER_NAME}' no existe."
        echo ""
    elif [ "$STATUS" = "false" ]; then
        echo ""
        echo " 🚀 Arrancando ${CONTAINER_NAME}..."
        echo ""
        docker start "${CONTAINER_NAME}"
        sleep 2
        FINAL_CHECK=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
        if [ "$FINAL_CHECK" = "true" ]; then
        echo ""
            echo " ✅ '$CONTAINER_NAME' se ha iniciado con exito."
        echo ""
        else
            echo ""
            echo " ❌ Error crítico: El contenedor '$CONTAINER_NAME' falló al arrancar."
            echo "--- Logs de "$CONTAINER_NAME" ---"
            docker logs --tail 20 "$CONTAINER_NAME"
            echo ""
            exit 1
        fi
    else
        echo ""
        echo " El contenedor '${CONTAINER_NAME}' ya está en ejecución."
        echo ""
    fi

}

container_check() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo ""
        echo " ❌ Error: Debes indicar el nombre del contenedor."
        echo ""
        return 1
    fi

    sleep 2

    FINAL_CHECK=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
    if [ "$FINAL_CHECK" = "true" ]; then
        echo ""
        echo " ✅ '$CONTAINER_NAME' se ha iniciado con exito."
        echo ""
    else
        echo ""
        echo " ❌ Error crítico: El contenedor '$CONTAINER_NAME' falló al arrancar."
        echo "--- Logs de '$CONTAINER_NAME' ---"
        echo ""
        docker logs --tail 20 "$CONTAINER_NAME" >&2
        exit 1
    fi
 
}

container_ok_message() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo ""
        echo " ❌ Error: Debes indicar el nombre del contenedor."
        echo ""
        return 1
    fi

    echo ""
    echo " El contenedor '${CONTAINER_NAME}' ya está en ejecución."
    echo ""

}

container_run_message() {

    CONTAINER_NAME="$1"

    if [ -z "$CONTAINER_NAME" ]; then
        echo ""
        echo " ❌ Error: Debes indicar el nombre del contenedor."
        echo ""
        return 1
    fi

    echo ""
    echo " 🚀 Creando e iniciando el contenedor '${CONTAINER_NAME}'..."
    echo ""

}

container_build_message() {

    CONTAINER_NAME="$1"
    IMAGE_NAME="$2"

    if [ -z "$CONTAINER_NAME" ]; then
        echo ""
        echo " ❌ Error: Debes indicar el nombre del contenedor."
        echo ""
        return 1
    fi

    echo ""
    echo " 🔄 Construyendo la imagen '${IMAGE_NAME}' en el contenedor '${CONTAINER_NAME}'..."
    echo ""

}

container_records_message() {

    CONTAINER_NAME="$1"
    RECORDS_NAME="$2"

    echo ""
    echo " 🔄 Instalando registros de ${RECORDS_NAME} en el contenedor '${CONTAINER_NAME}'..."
    echo ""

}

#  MongoDB

if [ "$CMD" = "run" ] && [ -n "${MONGO_VERSION:-}" ]; then

    CONTAINER_NAME="mongodb"
    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then

        if [ ! -d "$MONGO_DATA_DIR" ]; then
            # Ajustar permisos y no lo dejamos en manos del -v de docker
            container_dir "${MONGO_DATA_DIR}"
            mkdir -p "$MONGO_DATA_DIR"
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

        if [ -n "${MONGO_COLLECTIONS_DIR:-}" ]; then

            # Comprobar que existe el directorio de datos
            if [ ! -d "$MONGO_COLLECTIONS_DIR" ]; then
                echo ""
                echo " ❌ MongoDB collections directory not found: $MONGO_COLLECTIONS_DIR"
                exit 1
            fi

            # Esperar a que MongoDB esté disponible

            until docker exec "$CONTAINER_NAME" mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1
            do
                sleep 1
            done

            for MONGO_JSON_FILE in "$MONGO_COLLECTIONS_DIR"/*.json; do

                NAME=$(basename "$MONGO_JSON_FILE" .json)
                container_records_message "${CONTAINER_NAME}" ${NAME}

                DB="${NAME%%_*}"
                COLLECTION="${NAME#*_}"

                docker exec -i "$CONTAINER_NAME" mongoimport \
                    --db "$DB" \
                    --collection "$COLLECTION" \
                    --jsonArray \
                    < "$MONGO_JSON_FILE"

            done

        fi

            
    elif [ "$STATUS" = "false" ]; then
        container_start "${CONTAINER_NAME}"

    else
        container_ok_message "${CONTAINER_NAME}"

    fi


    # docker exec -it mongodb mongosh -u admin -p secretpassword --authenticationDatabase admin
fi

if [ "$CMD" = "upgrade" ] && [ -n "${MONGO_JSON_FILE:-}" ]; then

    NAME=$(basename "$MONGO_JSON_FILE" .json)
    container_records_message "${CONTAINER_NAME}" ${NAME}

    DB="${NAME%%_*}"
    COLLECTION="${NAME#*_}"

    docker exec -i "$CONTAINER_NAME" mongoimport \
        --db "$DB" \
        --collection "$COLLECTION" \
        --jsonArray \
        < "$MONGO_JSON_FILE"

fi


cerbot() {

    CERTBOT_IMAGE_NAME="certbot/certbot"

    # Directorio por defecto de la imagen Certbot -> letscript si no se especifica otro
    LETSENCRIPT="/etc/letsencrypt"

    # Comprobar que Nginx está corriendo
    if ! docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
        echo " ❌ Error: El contenedor de Nginx debe estar en ejecución para validar el certificado."
        exit 1
    fi

    echo " 🔒 Solicitando certificado SSL para: $CERTBOT_DOMAIN..."

    # Crear directorio temporal para el desafío HTTP
    mkdir -p "$CERTBOT_VALIDATOR_DIR"

    # Ejecutar contenedor efímero de Certbot
    docker run --rm \
        -v "$NGINX_CERTS_DIR:$LETSENCRIPT" \
        -v "$CERTBOT_VALIDATOR_DIR:$CERTBOT_VALIDATOR_PATH" \
        "${CERTBOT_IMAGE_NAME}" certonly \
        --webroot \
        --webroot-path="$CERTBOT_VALIDATOR_PATH" \
        --email "$CERTBOT_EMAIL" \
        --agree-tos \
        --no-eff-email \
        --keep-until-expiring \
        --non-interactive \
        -d "$CERTBOT_DOMAIN"
    then
        echo " ✅ Certificado emitido con éxito en: $NGINX_CERTS_DIR"
    else
        echo " ❌ Error al solicitar el certificado SSL."
        exit 1
    fi

}



# Nginx

if [ "$CMD" = "run" ] && [ -n "${NGINX_HTML_FOLDER:-}" ]; then

    CONTAINER_NAME="nginx"
    NGINX_HTML_IMAGE_NAME="document-root"

    STATUS=$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then

        if [ -n "${CERTBOT_DOMAIN:-}" ] && [ -n "${CERTBOT_EMAIL:-}" ]; then
            cerbot
        fi

        container_build_message "${CONTAINER_NAME}" "${NGINX_HTML_IMAGE_NAME}"
        docker build -t "${NGINX_HTML_IMAGE_NAME}" "${NGINX_HTML_FOLDER}"

        container_run_message "${CONTAINER_NAME}"

        if [ -n "${CERTBOT_DOMAIN:-}" ] && [ -n "${CERTBOT_EMAIL:-}" ]; then
            docker run -d \
                --name "$CONTAINER_NAME" \
                --network "$NETWORK_NAME" \
                --restart unless-stopped \
                -p 80:80 \
                -p 443:443 \
                -v "$NGINX_CERTS_DIR:/etc/nginx/certs:ro" \
                -v "$CERTBOT_VALIDATOR_DIR:$CERTBOT_VALIDATOR_PATH:ro" \
                "$NGINX_HTML_IMAGE_NAME"
        else
            docker run -d \
                --name "$CONTAINER_NAME" \
                --network "$NETWORK_NAME" \
                --restart unless-stopped \
                -p 80:80 \
                -p 443:443 \
                -v "$NGINX_CERTS_DIR:/etc/nginx/certs:ro" \
                "$NGINX_HTML_IMAGE_NAME"
        fi

        container_check "${CONTAINER_NAME}"
            
    elif [ "$STATUS" = "false" ]; then
        container_start "${CONTAINER_NAME}"

    else
        container_ok_message "${CONTAINER_NAME}"

    fi


    # echo " 🛑 Deteniendo y limpiando el contenedor "$NGINX_CONTAINER_NAME" ..."
    # docker stop "$NGINX_CONTAINER_NAME" 2>/dev/null || true
    # docker rm "$NGINX_CONTAINER_NAME" 2>/dev/null || true

fi

run_express() {

    EXPRESS_CONTAINER_NAME="expressjs"
    EXPRESS_IMAGE_NAME="express-app"

    STATUS=$(docker inspect --format '{{.State.Running}}' "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then

        container_build_message "${EXPRESS_CONTAINER_NAME}" "${EXPRESS_IMAGE_NAME}"
        docker build -t "${EXPRESS_IMAGE_NAME}" "${EXPRESS_FOLDER}"

        container_run_message "${EXPRESS_CONTAINER_NAME}"
        docker run -d \
            --name "$EXPRESS_CONTAINER_NAME" \
            --network "$NETWORK_NAME" \
            "${EXPRESS_IMAGE_NAME}"

        container_check "${EXPRESS_CONTAINER_NAME}"

    elif [ "$STATUS" = "false" ]; then
        container_start "${EXPRESS_CONTAINER_NAME}"

    else
        container_ok_message "${EXPRESS_CONTAINER_NAME}"

    fi

    # echo "Limpiando contenedor previo si existe..."
    # docker stop "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true
    # docker rm "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true

}

# ExpressJS

if [ "$CMD" = "run" ] && [ -n "${EXPRESS_FOLDER:-}" ]; then

    run_express

fi



if [ "$CMD" = "upgrade" ] && [ "$MODULE" = "expressjs" ] && [ -n "${EXPRESS_FOLDER:-}" ]; then

    EXPRESS_CONTAINER_NAME="expressjs"
    EXPRESS_IMAGE_NAME="express-app"

    STATUS=$(docker inspect --format '{{.State.Running}}' "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true)

    if [ -z "$STATUS" ]; then
        echo "Nothing installed. Continue"

    elif [ "$STATUS" = "false" ]; then
        docker rmi "${EXPRESS_IMAGE_NAME}"
        docker rm "${EXPRESS_CONTAINER_NAME}"

    else
        docker stop "${EXPRESS_CONTAINER_NAME}"
        docker rmi "${EXPRESS_IMAGE_NAME}"
        docker rm "${EXPRESS_CONTAINER_NAME}"

    fi

    run_express

    # echo "Limpiando contenedor previo si existe..."
    # docker stop "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true
    # docker rm "${EXPRESS_CONTAINER_NAME}" 2>/dev/null || true


elif [ "$CMD" = "upgrade" ] && [ "$MODULE" = "expressjs" ]; then
    echo "No express configured"
    exit 1
fi

if [ "$CMD" = "remove" ]; then

    echo ""

    echo " 🚀 Parando todas las instancias de docker"
    docker stop $(docker ps -q) 2>/dev/null

    echo " 🚀 Podando el container"
    docker container prune -f

    step=1

    case "$ID" in
        amzn)
            if [ "$VERSION_ID" = "2023" ]; then
                echo ""
                echo "Para terminar la eliminación teclee:"
                echo "$step. sudo dnf remove -y docker docker-ce docker-ce-cli containerd.io docker-compose-plugin"
                step=$((step + 1))
                echo "$step. sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker"

            elif [ "$VERSION_ID" = "2" ]; then
                echo ""
                echo "Para terminar la eliminación teclee:"
                echo "$step. sudo yum remove -y docker"
                step=$((step + 1))
                echo "$step. sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker"
                step=$((step + 1))

            else
                echo " ❌ Versión de Amazon Linux ($VERSION_ID) no soportada por este script."
                exit 1
            fi
            ;;
            
        ubuntu|debian)
            echo ""
            echo "Para terminar la eliminación teclee:"
            echo ""
            echo "$step. sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras"
            step=$((step + 1))
            echo "$step. sudo apt-get autoremove -y --purge"
            step=$((step + 1))
            echo "$step. sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker"
            step=$((step + 1))
            ;;

        rhel|centos|rocky|almalinux)
            echo " ❌ No hay script"
            ;;
            
        *)
            echo " ❌ Sistema operativo no soportado: $ID"
            exit 1
            ;;
    esac

    if [ -n "${MONGO_DATA_DIR:-}" ]  && [ -d "${MONGO_DATA_DIR}" ]; then
        echo "$step. Please check dir ${MONGO_DATA_DIR} of MongoDB installation."
        step=$((step + 1))
    fi

    if [ -n "${NGINX_CERTS_DIR:-}" ]  && [ -d "${NGINX_CERTS_DIR}" ]; then
        echo "$step. Please check dir ${NGINX_CERTS_DIR} of Letencrypt/NGINX installation."
        step=$((step + 1))
    fi

    if [ -n "${CERTBOT_VALIDATOR_DIR:-}" ]  && [ -d "${CERTBOT_VALIDATOR_DIR}" ]; then
        echo "$step. Please check dir ${CERTBOT_VALIDATOR_DIR} of Letencrypt/NGINX installation."
        step=$((step + 1))
    fi

    echo ""

fi



if [ "$CMD" = "certbot" ]; then

    cerbot

    echo " 🔄 Recargando Nginx para aplicar cambios SSL..."
    docker exec nginx nginx -s reload

fi



if [ "$CMD" = "mongosh" ]; then
    docker exec -it mongodb mongosh
fi
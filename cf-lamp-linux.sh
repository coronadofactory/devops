#!/bin/sh

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
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo ""
    echo " ❌ No se pudo identificar el sistema operativo."
    exit 1
fi

while [ $# -gt 0 ]
do
    case "$1" in
        "update") 
            echo "📦 Actualizando Linux..."
        ;;
        *)
            echo "Unknown parameter $1"
            exit 1
        ;;
    esac
    shift;
done


if systemctl is-active --quiet httpd; then
    echo ""
    echo "Paramos Apache para detener las conexiones"
    echo "systemctl stop httpd"
    sudo systemctl stop httpd
    echo "Esperamos 10 segundos a que acaben las transacciones en curso"
    sleep 10
fi

if systemctl is-active --quiet mysqld.service; then
    echo ""
    echo "Paramos la base de datos"
    echo "systemctl stop mysqld"
    sudo systemctl stop mysqld
fi


case "$ID" in
    amzn)

        if [ "$VERSION_ID" = "2" ]; then
            echo ""
            echo "Actualizamos usando yum"
            echo "yum update --disablerepo='mysql*'"
            sudo yum update --disablerepo='mysql*'

        elif [ "$VERSION_ID" = "2023" ]; then
            echo ""
            echo "Actualizamos usando dnf"
            echo "dnf update"
            sudo dnf update

        else
            echo ""
            echo " ❌ Versión de Amazon Linux ($VERSION_ID) no soportada por este script."
            exit 1
        fi
        ;;
        
    *)
        echo ""
        echo " ❌ Sistema operativo no soportado: $ID"
        exit 1
        ;;
esac
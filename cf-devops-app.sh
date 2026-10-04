#!/bin/sh

##
## Devops Docker App Installer
## 
## Copyright (c) 1984-2026 Jose Garcia
## Released under the MIT license
## https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
## 
## Description: Script universal para instalar aplicaciones 
## Date: 2026-10-04
## 

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

case "$1" in
    install)
        CMD=$1
        if [ -n "${2:-}" ]; then
            APP="$2"
        else 
            echo "No app specifiend"
            exit 1
        fi
        ;;
    upgrade)
        CMD=$1
        if [ -n "${2:-}" ]; then
            APP="$2"
        else 
            echo "No app specifiend"
            exit 1
        fi

        case "$3" in
            expressjs)
                MODULE="$3"
                ;;
            "")
                echo "No module defined. Expected expressjs"
                exit 1
                ;;
            *)
                echo "Invalid module: $3. Expected expressjs."
                exit 1
                ;;
        esac
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

INBOX_DIR="/var/cf-inbox"
APP_PACKAGE="$INBOX_DIR/$APP-app.zip"
APP_PACKAGE_UPGRADE="$INBOX_DIR/$APP-${MODULE:-}-upgrade.zip"
APP_DIR="/opt/mbox/$APP"

if [ ! -d "$INBOX_DIR" ]; then
    echo "Not $INBOX_DIR created"
    exit 1
elif [ "$CMD" = "install" ] && [ ! -f "$APP_PACKAGE" ]; then
    echo "Not $APP_PACKAGE to install"
    exit 1
elif [ "$CMD" = "install" ] && [ -d "$APP_DIR" ]; then
    echo "$APP_DIR exists"
    exit 1
elif [ "$CMD" = "upgrade" ] && [ ! -f "$APP_PACKAGE_UPGRADE" ]; then
    echo "Not $APP_PACKAGE_UPGRADE to upgrade"
    exit 1
elif [ "$CMD" = "upgrade" ] && [ ! -d "$APP_DIR" ]; then
    echo "Not $APP_DIR created"
    exit 1
fi


if [ "$CMD" = "install" ]; then
    mkdir "$APP_DIR"
    unzip -o "$APP_PACKAGE" -d "$APP_DIR" || exit 1
    (
        cd "$APP_DIR" || exit 1
        cf docker run
    )
fi

if [ "$CMD" = "upgrade" ]; then
    unzip -o "$APP_PACKAGE_UPGRADE" -d "$APP_DIR" || exit 1
    (
        cd "$APP_DIR" || exit 1
        cf docker upgrade "$MODULE"
    )
fi
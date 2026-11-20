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

if [ "$#" -eq 0 ]; then
    echo "Error: No parameters provided"
    exit 1
fi

while [ $# -gt 0 ]
do
    case "$1" in
        "install") 
            cmd="$1"
        ;;
        "-version") 
            if  [ $# -lt 2 ]; then
                echo "Please specify version in -version value"
                exit
            fi
            shift;
            VERSION=$1
        ;;
        "-dir") 
            if  [ $# -lt 2 ]; then
                echo "Please specify dir in -dir value"
                exit
            fi
            shift;
            DIR=$1
        ;;
        *)
            echo "Unknown parameter $1"
            exit
        ;;
    esac
    shift;
done

if [ -z "${VERSION:-}" ]; then
    echo " ❌ No version specified"
    exit 1
elif [ -z "${DIR:-}" ]; then
    echo " ❌ No dir specified"
    exit 1
elif [ ! -d "${DIR:-}" ]; then
    echo " ❌ No DIR found"
    exit 1
fi

echo "📦 Instalando Tomcat (${VERSION})..."


MAJOR=${VERSION%%.*}
FILE="apache-tomcat-${VERSION}.tar.gz"
URL="https://dlcdn.apache.org/tomcat/tomcat-${MAJOR}/v${VERSION}/bin/${FILE}"
DEST="/usr/share"

# Download with curl, or fall back to wget
echo "Downloading $URL"
if command -v curl >/dev/null 2>&1; then
    if ! curl -fL -o "$DIR/$FILE" "$URL"; then
        rc=$?
        echo "Error: download failed (curl exit code $rc): $URL" >&2
        rm -f "$DIR/$FILE"
        exit 1
    fi
else
    echo " ❌ curl no installed"
    exit 1
fi

echo "tar -xzf $DIR/$FILE -C $DEST"
tar -xzf "$DIR/$FILE" -C "$DEST"

echo "Extracted to $DEST"
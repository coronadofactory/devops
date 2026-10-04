#!/bin/sh

##
## cf-installer.sh
## 
## Copyright (c) 1984-2026 Jose Garcia
## Released under the MIT license
## https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
##
## Description: Scripts de descarga de cf commands en una maquina a dockerizar
#
## Date: 2024-10-03
## Rev: 2026-10-04




case "$1" in
    install)
        CMD=$1
        ;;
    *)
        echo ""
        echo "Invalid command: $1"
        exit 1
        ;;
esac


case "$2" in
    server)
        MODULE=$2
        ;;
    "")
        echo ""
        echo "No module spcified"
        exit 1
        ;;
    *)
        echo ""
        echo "Invalid module $2 for command $1"
        exit 1
        ;;
esac



if [ "$(id -u)" -ne 0 ]; then
    echo ""
    echo "Por favor, ejecuta este script como root o usando sudo."
    exit 1
fi


set -eu



git="https://raw.githubusercontent.com/coronadofactory/devops/refs/heads/main"
lib="/usr/local/lib/coronadofactory"
bin="/usr/local/bin/coronadofactory"



download() {

   FILE="$1"
   URL="$git/$FILE"
   DEST="$lib/$FILE"

   mkdir -p $lib

   if [ -f "$DEST" ]; then
        echo "File already exists: $DEST"
        return 1
   elif ! curl -fsS "$URL" -o "$DEST"; then
       echo "Error downloading $URL" >&2
       exit 1
   fi

   chmod +x "$DEST"

}



if [ "$MODULE" = "server" ]; then

    download cf.sh
    download cf-devops-docker.sh
    download cf-devops-app.sh

    if [ ! -e "$bin/cf" ]; then
        ln -s $lib/cf.sh $bin/cf
    fi

    if [ ! -d "/var/cf-inbox" ]; then
        mkdir /var/cf-inbox
    fi


fi
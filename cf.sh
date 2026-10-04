#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
    echo "Please use $(whoami) user"
    exit
fi


lib="/usr/local/lib/coronadofactory"

re="(docker|app)"
if [[ $1 =~ $re ]]; then
    MODULE=$1
    shift
    $lib/cf-devops-$MODULE.sh "$@"
    exit
fi
#!/bin/sh

if [ "$(whoami)" != "root" ] ; then
    echo "Please use $(whoami) user"
    exit
fi



re="(docker)"
if [[ $1 =~ $re ]]; then
    shift
    /usr/local/lib/coronadofactory/cf-devops-docker.sh "$@"
    exit
fi
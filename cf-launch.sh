#!/bin/sh

#
# cf
# 
# Copyright (c) 1984-2024 Jose Garcia
# Released under the MIT license
# https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
#
# Date: 2024-10-03
#

git="https://raw.githubusercontent.com/coronadofactory"

re="(install)"
if [[ $1 =~ $re ]]; then
   case "$1" in
      *)  cmd=$1
      ;;
   esac
   shift
else 
   echo "Unknown command $1"
   exit
fi



re="(install)"
if [[ $cmd =~ $re ]]; then

   front="(react|webpack|appia|backend|form|proxy)"
   devops="(cookies|analytics|youtube)"
   if [[ $1 =~ $front ]]; then
      curl -s $git/hexagonal/refs/heads/main/front/cf.sh | sh -s $1
   elif [[ $1 =~ $devops ]]; then
      curl -s $git/site-builder/refs/heads/master/cf.sh | sh -s $1
   else
      echo "Unknown $1"
      exit
   fi

fi
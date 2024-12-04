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

   re="(appia|backend|form|react|proxy)"
   if [[ $1 =~ $re ]]; then
      curl -s https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/front/cf.sh | sh -s $1
   else
      re="(cookies|analytics|youtube)"
      if [[ $1 =~ $re ]]; then
         curl -s https://raw.githubusercontent.com/coronadofactory/site-builder/refs/heads/master/cf.sh | sh -s $1
      else
         echo "Unknown $1"
      fi
   fi

   exit

fi
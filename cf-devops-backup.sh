#!/bin/sh

##
## Devops Backup
## 
## Copyright (c) 1984-2026 Jose Garcia
## Released under the MIT license
## https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
## 
## Description: Multi backup 
## Date: 2026-10-26
## Updates: Multi s3

init_checks() {

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

}

starting() {

    d=$(date +"%Y-%m-%d.%H:%M")
    echo "--------------------------------------"
    echo "starting:$1 local:$2  $d" >> $3

}

finished() {

    d=$(date +"%Y-%m-%d.%H:%M")
    echo "finished:$1 local:$2 $d" >> $3

}

protect_local() {

    chmod 400 $1

}

check_local_gzip() {

    if gzip -t "$1" > /dev/null 2>&1; then
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:check status:success file:$1 date:$d" >> $2
    else 
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:check status:error file:$1 date:$d params:t" >> $2
        exit 1
    fi

}

send_offsite() {
    
    for value3 in $3; do
        case "$value3" in
            s3:*)
                s3_offsite "$1" "$2" "$value3"
                ;;
            cp:*)
                cp_offsite "$1" "$2" "$value3"
                ;;
            *)
                echo "Unknown offsite type: $offsite" >&2
                ;;
        esac
    done
    
}

s3_offsite() {

    aws_cmd="`which aws`"

    for value in $(printf '%s\n' "$3" | tr '|' ' '); do
        echo "${aws_cmd} s3 cp $1 $value/"
        echo "${aws_cmd} s3 cp $1 $value/" >> $2
        ${aws_cmd} s3 cp $1 $value/
        if [ "$?" != "0" ]; then
            echo "trace:s3cp status:error file:$1 s3:$value/" >> $2
            exit 1
        fi
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:s3cp status:success file:$1 s3:$value/" >> $2
    done
    
}

cp_offsite() {

    value3="${3#cp:}"

    echo "cp -v $1 ${value3}"
    cp -v $1 ${value3}
    if [ "$?" != "0" ]; then
        echo "trace:cp status:error file:$1 to:${value3}" >> $2
        exit 1
    fi
    d=$(date +"%Y-%m-%d.%H:%M")
    echo "trace:cp status:success file:$1 to:${value3}" >> $2

}

dir_backup() {

    init_checks

    dirs=""
    local=""
    offsites=""
    log=""

    while [ $# -gt 0 ]; do
    case "$1" in
        "-dir") 
            if  [ $# -eq 1 ]; then
                echo "Please specify db in -db value"
                exit 1
            fi
            shift;
            dirs="${dirs:+$dirs }$1"
            ;;
        "-local") 
            if  [ $# -eq 1 ]; then
                echo "Please specify local in -local value"
                exit 1
            fi
            shift;
            local=$1
            ;;
        "-offsite") 
            if  [ $# -eq 1 ]; then
                echo "Please specify offsite in -offsite value"
                exit 1
            fi
            shift;
            offsites="${offsites:+$offsites|}$1"
            ;;
        "-log") 
            if  [ $# -eq 1 ]; then
                echo "Please specify log in -log value"
                exit 1
            fi
            shift;
            log=$1
            ;;
        *)
            echo "Unknown parameter $1"
            exit 1
            ;;
    esac
    shift;
    done

    if [ -z "${dirs:-}" ]; then
        echo " ❌ No dir defined"
        exit 1
    elif [ -z "${local:-}" ]; then
        echo " ❌ No local defined"
        exit 1
    elif [ -z "${log:-}" ]; then
        echo " ❌ No log defined"
        exit 1
    fi

    date=$(date +"%Y-%m-%d %H:%M")

    starting dir_backup $local $log

    echo "tar -czf $local.tar.gz $dirs"
    echo "tar -czf $local.tar.gz $dirs" >> $log
    error=$(tar -czf "$local".tar.gz "$dirs"  2>&1)
    if [ "$?" != "0" ]; then
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:tar status:error file:$local.tar.gz dirs:$dirs params:czf date:$d message:$error" >> $log
        exit 0
    fi

    d=$(date +"%Y-%m-%d.%H:%M")
    echo "trace:tar status:success file:$local.tar.gz dirs:$dirs params:czf date:$d" >> $log

    protect_local $local.tar.gz

    check_local_gzip $local.tar.gz $log

    if [ -n "${offsites:-}" ]; then
        send_offsite $local.tar.gz $log $offsites
    fi

    finished dir_backup $local $log

}

mysql_backup() {

    if [ -z "${mysqluser:-}" ]; then
        echo " ❌ No mysqluser defined"
        exit 1
    elif [ -z "${mysqlpassword:-}" ]; then
        echo " ❌ No mysqlpassword defined"
        exit 1
    fi

    db=""
    table=""
    local=""
    offsites=""
    log=""

    while [ $# -gt 0 ]; do
    case "$1" in
        "-fulldb") 
            db="--all-databases"
            ;;
        "-db") 
            if  [ $# -eq 1 ]; then
                echo "Please specify db in -db value"
                exit
            fi
            shift;
            db=$1
            ;;
        "-table") 
            if  [ $# -eq 1 ]; then
                echo "Please specify table in -table value"
                exit
            fi
            shift;
            table=$1
            ;;
        "-local") 
            if  [ $# -eq 1 ]; then
                echo "Please specify local in -local value"
                exit
            fi
            shift;
            local=$1
            ;;
        "-offsite") 
            if  [ $# -eq 1 ]; then
                echo "Please specify offsite in -offsite value"
                exit
            fi
            shift;
            offsites="${offsites:+$offsites|}$1"
            ;;
        "-log") 
            if  [ $# -eq 1 ]; then
                echo "Please specify log in -log value"
                exit
            fi
            shift;
            log=$1
            ;;
        *)
            echo "Unknown parameter $1"
            exit
            ;;
    esac
    shift;
    done

    if [ -z "${db:-}" ]; then
        echo " ❌ No db defined"
        exit 1
    elif [ -z "${local:-}" ]; then
        echo " ❌ No local defined"
        exit 1
    elif [ -z "${log:-}" ]; then
        echo " ❌ No log defined"
        exit 1
    fi

    starting mysql_backup $local $log

    dbopt=" --routines --triggers --events --single-transaction --create-options --set-charset"

    if [ -z "$table" ]; then
        echo "mysqldump -u $mysqluser -p<hidden> $dbopt $db | gzip > $local.sql.gz"
        echo "mysqldump -u $mysqluser -p<hidden> $dbopt $db | gzip > $local.sql.gz" >> $log
        mysqldump -u $mysqluser -p$mysqlpassword $dbopt $db | gzip > $local.sql.gz
        if [ "$?" != "0" ]; then
            d=$(date +"%Y-%m-%d.%H:%M")
            echo "trace:mysqldump status:error file:$local.sql.gz db:$db date:$d" >> $log
            exit 1
        fi
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:mysqldump status:success file:$local.sql.gz db:$db date:$d" >> $log
    else
        echo "mysqldump -u $mysqluser -p<hidden> $dbopt $db $table | gzip > $local.sql.gz"
        echo "mysqldump -u $mysqluser -p<hidden> $dbopt $db $table | gzip > $local.sql.gz" >> $log
        mysqldump -u $mysqluser -p$mysqlpassword $dbopt $db $table | gzip > $local.sql.gz
        if [ "$?" != "0" ]; then
            d=$(date +"%Y-%m-%d.%H:%M")
            echo "trace:mysqldump status:error file:$local.sql.gz db:$db table:$table date:$d" >> $log
            exit 1
        fi
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:mysqldump status:success file:$local.sql.gz db:$db table:$table date:$d" >> $log
    fi


    protect_local $local.sql.gz

    check_local_gzip $local.sql.gz $log

    if [ -n "${offsites:-}" ]; then
        send_offsite $local.sql.gz $log $offsites
    fi

    finished mysql_backup $local $log

}

mongo_backup() {

    dbparm=""
    local=""
    offsites=""
    log=""

    while [ $# -gt 0 ]; do
    case "$1" in
        "-fulldb") 
            dbparm="fulldb"
            ;;
        "-db") 
            if  [ $# -eq 1 ]; then
                echo "Please specify db in -db value"
                exit
            fi
            shift;
            dbparm="${dbparm:+$dbparm }$1"
            ;;
        "-local") 
            if  [ $# -eq 1 ]; then
                echo "Please specify local in -local value"
                exit
            fi
            shift;
            local=$1
            ;;
        "-offsite") 
            if  [ $# -eq 1 ]; then
                echo "Please specify offsite in -offsite value"
                exit
            fi
            shift;
            offsites="${offsites:+$offsites }$1"
            ;;
        "-log") 
            if  [ $# -eq 1 ]; then
                echo "Please specify log in -log value"
                exit
            fi
            shift;
            log=$1
            ;;
        *)
            echo "Unknown parameter $1"
            exit
            ;;
    esac
    shift;
    done

    if [ -z "${dbparm:-}" ]; then
        echo " ❌ No db defined"
        exit 1
    elif [ -z "${local:-}" ]; then
        echo " ❌ No local defined"
        exit 1
    elif [ -z "${log:-}" ]; then
        echo " ❌ No log defined"
        exit 1
    fi

    starting mongodb_backup $local $log

    if [ "$dbparm" = "fulldb" ]; then
        echo "mongodump --archive=$local.gz --gzip"
        mongodump --archive="$local.gz" --gzip
        if [ "$?" != "0" ]; then
            d=$(date +"%Y-%m-%d.%H:%M")
            echo "trace:mongodump status:error file:$local.gz db:$dbparm date:$d" >> $log
            exit
        fi
        d=$(date +"%Y-%m-%d.%H:%M")
        echo "trace:mongodump status:success file:$local.gz db:$dbparm date:$d" >> $log
    fi


    protect_local $local.gz

    check_local_gzip $local.gz $log

    if [ -n "${offsites:-}" ]; then
        send_offsite $local.gz $log $offsites
    fi

    finished mongodb_backup $local $log

}
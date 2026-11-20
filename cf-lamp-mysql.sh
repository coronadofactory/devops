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

if [ "$#" -eq 0 ]; then
    echo "Error: No parameters provided"
    exit 1
fi

echo ["$@"]

while [ $# -gt 0 ]
do
    case "$1" in
        install|users) 
            cmd="$1"
        ;;
        "-datadir") 
            if  [ $# -lt 2 ]; then
                echo "Please specify dir in -datadir value"
                exit
            fi
            shift;
            MYSQL_DATA_DIR=$1
        ;;
        "-logdir") 
            if  [ $# -lt 2 ]; then
                echo "Please specify dir in -logdir value"
                exit
            fi
            shift;
            MYSQL_LOG_DIR=$1
        ;;
        "-logfile") 
            if  [ $# -lt 2 ]; then
                echo "Please specify dir in -logfile value"
                exit
            fi
            shift;
            MYSQL_LOG_FILE=$1
        ;;
        "start") 
            if ! rpm -q mariadb105-server >/dev/null 2>&1; then
                echo " ❌ MySQL no installed"
                exit 1
            elif systemctl is-active --quiet mariadb; then
                echo " ❌ MySQL started"
                exit 1
            fi
            sudo systemctl start mariadb || exit 1
            echo "✅ MariaDB started successfully"
            exit
        ;;
        "stop") 
            if ! rpm -q mariadb105-server >/dev/null 2>&1; then
                echo " ❌ MySQL no installed"
                exit 1
            elif ! systemctl is-active --quiet mariadb; then
                echo " ❌ MySQL not started"
                exit 1
            fi
            sudo systemctl stop mariadb || exit 1
            echo "✅ MariaDB stopped successfully"
            exit
        ;;
        "-user") 
            if  [ $# -lt 2 ]; then
                echo "Please specify user in -user value"
                exit
            fi
            shift;
            MYSQL_DBUSER=$1
        ;;
        "-filename") 
            if  [ $# -lt 2 ]; then
                echo "Please specify filename in -filename value"
                exit
            fi
            shift;
            MYSQL_EXPORT_FILE=$1
        ;;
        *)
            echo "Unknown parameter $1"
            exit
        ;;
    esac
    shift;
done

if [ -z "${cmd:-}" ]; then
    echo " ❌ Invalid command $1"
    exit 1
fi

if [ "$cmd" = "install" ]; then
    if [ -z "${MYSQL_DATA_DIR:-}" ]; then
        echo " ❌ -datadir not specified"
        exit 1
    elif [ ! -d "$MYSQL_DATA_DIR" ]; then
        echo " ❌ ${MYSQL_DATA_DIR} not created"
        exit 1
    elif [ -z "${MYSQL_LOG_DIR:-}" ]; then
        echo " ❌ -logdir not specified"
        exit 1
    elif [ ! -d "$MYSQL_LOG_DIR" ]; then
        echo " ❌ ${MYSQL_LOG_DIR} not created"
        exit 1
    elif [ -z "${MYSQL_LOG_FILE:-}" ]; then
        echo " ❌ -logfile not specified"
        exit 1
    fi

elif [ "$cmd" = "users" ]; then
    if [ -z "${MYSQL_DBUSER:-}" ]; then
        echo " ❌ -user not specified"
        exit 1
    elif [ -z "${MYSQL_EXPORT_FILE:-}" ]; then
        echo " ❌ -filename not specified"
        exit 1
    fi

fi

echo "📦 Instalando MySQL (MariaDB)..."

install_mariadb_dnf() {

    # 1. Instalamos la base de datos
    sudo dnf install mariadb105-server -y || exit 1

    # 2. Arrancamos la primera vez para que cree la bd
    sudo systemctl start mariadb || exit 1

    # 3. La ponemos con autoarranque
    sudo systemctl enable mariadb || exit 1

    # 4. Establecemos la contraseña
    printf "Enter password for root: "
    read -r ROOT_PASSWORD

    printf "Enter confirm password for root: "
    read -r ROOT_PASSWORD2

    if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD2" ]; then
        echo "Values match"
    else
        echo "Values do not match"
        exit
    fi
    SQL_PASSWORD=$(printf '%s' "$ROOT_PASSWORD" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g")
    if ! sudo mariadb --protocol=socket -e \
        "ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_PASSWORD}'; FLUSH PRIVILEGES;"; then
        echo "❌ Error configurando la contraseña de root."
        unset ROOT_PASSWORD SQL_PASSWORD
        exit 1
    fi

    # 5. La paramos para configurar los data
    sudo systemctl stop mariadb || exit 1

    # 6. Asignarle la propiedad al usuario y grupo 'mysql'
    echo "chown mysql:mysql ${MYSQL_DATA_DIR}"
    sudo chown mysql:mysql "${MYSQL_DATA_DIR}"
    echo "chmod 700 ${MYSQL_DATA_DIR}"
    sudo chmod 700 "${MYSQL_DATA_DIR}"
    echo "chown mysql:mysql ${MYSQL_LOG_DIR}"
    sudo chown mysql:mysql "${MYSQL_LOG_DIR}"
    echo "chmod 700 ${MYSQL_LOG_DIR}"
    sudo chmod 700 "${MYSQL_LOG_DIR}"

    # 7. Movemos los datos del directorio por defecto
    echo "sudo cp -R -p -v /var/lib/mysql/* ${MYSQL_DATA_DIR}"
    sudo cp -R -p /var/lib/mysql/* "${MYSQL_DATA_DIR}"

    # 8. Permisos
    if [ "$ID" = "amzn" ] && [ "$VERSION_ID" = "2023" ]; then
        echo "sudo semanage fcontext -a -t mysqld_db_t \"${MYSQL_DATA_DIR}(/.*)?\""
        sudo semanage fcontext -a -t mysqld_db_t "${MYSQL_DATA_DIR}(/.*)?"
        echo "sudo restorecon -Rv ${MYSQL_DATA_DIR}"
        sudo restorecon -Rv "${MYSQL_DATA_DIR}"
    fi

    # 9. Instrucciones para modificar /etc/my.cnf.d/mariadb-server.cnf
    
cat <<EOF

╔═════════════════════════════════════╗
║         MARIADB CONFIGURATION       ║
╚═════════════════════════════════════╝

1. Edit the configuration file:

   sudo vi /etc/my.cnf.d/mariadb-server.cnf

2. Add the following configuration:

[mysqld]
datadir=${MYSQL_DATA_DIR}
socket=${MYSQL_DATA_DIR}/mysql.sock
log_error=${MYSQL_LOG_DIR}/${MYSQL_LOG_FILE}

3. Edit the configuration file:

   sudo vi /etc/my.cnf.d/client.cnf

4. Add the following configuration:

[client]
socket=${MYSQL_DATA_DIR}/mysql.sock

5. Start MySQL:

   sudo cf start mysql

EOF


}




if [ "$cmd" = "install" ]; then

    case "$ID" in
        amzn)
            if [ "$VERSION_ID" = "2023" ]; then

                if ! rpm -q mariadb105-server >/dev/null 2>&1; then
                    echo "Usando DNF para Amazon Linux 2023..."
                    dnf update -y
                    install_mariadb_dnf

                elif ! systemctl is-active --quiet mariadb; then
                    echo "⚠️ MySQL está instalada, pero parada."
                    echo "Ejecute: cf start mysql"

                else
                    echo "✅ MySQL ya está instalada y en ejecución."

                fi

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

fi



if [ "$cmd" = "users" ]; then

    if [ -z "${MYSQL_DBUSER:-}" ]; then
        echo " ❌ -user not specified"
        exit 1
    elif [ -z "${MYSQL_EXPORT_FILE:-}" ]; then
        echo " ❌ -filename not specified"
        exit 1
    fi

    printf "Enter password for root: "
    read -r ROOT_PASSWORD

    printf "Enter confirm password for root: "
    read -r ROOT_PASSWORD2

    if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD2" ]; then
        echo "Values match"
    else
        echo "Values do not match"
        exit
    fi
    SQL_PASSWORD=$(printf '%s' "$ROOT_PASSWORD" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g")

    echo "" > $MYSQL_EXPORT_FILE
    chmod 700 $MYSQL_EXPORT_FILE

    # MySQL connection
    MYSQL=(mysql --user="$MYSQL_DBUSER" \
        --password="$SQL_PASSWORD" \
        --batch \
        --skip-column-names \
        --raw)

    echo "======================================"
    echo " MySQL Users and Privileges Export"
    echo "======================================"

    # Test connection
    "${MYSQL[@]}" -e "SELECT VERSION();" >/dev/null

    echo "Connection successful!"
    echo "Generating export: $MYSQL_EXPORT_FILE"

    # ==========================================
    # EXPORT USERS AND PRIVILEGES
    # ==========================================

    {
        echo "-- MySQL users and privileges export"
        echo "-- Date: $(date)"
        echo "-- Review compatibility before importing"
        echo ""

        # Get users
        "${MYSQL[@]}" -e "
            SELECT user, host
            FROM mysql.user
            WHERE user NOT IN (
                'mysql.infoschema',
                'mysql.session',
                'mysql.sys'
            )
            ORDER BY user, host;
        " | while IFS=$'\t' read -r USER HOST; do

            echo ""
            echo "-- =================================="
            echo "-- USER: ${USER}@${HOST}"
            echo "-- =================================="

            # Get authentication information
            AUTH=$("${MYSQL[@]}" -e "
                SELECT
                    COALESCE(plugin,''),
                    COALESCE(authentication_string,'')
                FROM mysql.user
                WHERE user = '${USER}'
                AND host = '${HOST}'
                LIMIT 1;
            ")

            PLUGIN=$(printf '%s\n' "$AUTH" | head -n 1 | cut -f1)
            HASH=$(printf '%s\n' "$AUTH" | head -n 1 | cut -f2-)

            # Create user
            if [[ -n "$HASH" && -n "$PLUGIN" ]]; then

                printf "CREATE USER IF NOT EXISTS '%s'@'%s' IDENTIFIED WITH '%s' AS '%s';\n" \
                    "$USER" "$HOST" "$PLUGIN" "$HASH"

            else

                printf "CREATE USER IF NOT EXISTS '%s'@'%s';\n" \
                    "$USER" "$HOST"

            fi

            # Export grants
            echo "-- PRIVILEGES"

            "${MYSQL[@]}" -e "SHOW GRANTS FOR '${USER}'@'${HOST}';" |
            while IFS= read -r GRANT; do
                printf '%s;\n' "$GRANT"
            done

        done

        echo ""
        echo "-- END OF EXPORT"

    } >> "$MYSQL_EXPORT_FILE"

    echo ""
    echo "======================================"
    echo " EXPORT COMPLETED"
    echo "======================================"
    echo "File: $MYSQL_EXPORT_FILE"
    echo "Size: $(du -h "$MYSQL_EXPORT_FILE" | cut -f1)"
    echo ""
    echo "IMPORTANT:"
    echo "Review authentication syntax before importing."
    echo "Do not restore system tables directly."
    echo "mysql --default-character-set=utf8mb4 -u root -p < $MYSQL_EXPORT_FILE"

fi
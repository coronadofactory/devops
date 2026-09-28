#!/bin/sh

#
# cf-install-docker-app.sh
# 
# Copyright (c) 1984-2026 Jose Garcia
# Released under the MIT license
# https://raw.githubusercontent.com/coronadofactory/hexagonal/refs/heads/main/LICENSE.txt
#
# Date: 2026-06-24
#

# Comprobamos usuario
if [ "$(whoami)" != "ec2-user" ] ; then
    echo "Please use ec2-user user"
    exit
fi

# 1. Actualizacion de software
echo "1. Actualizacion de software en la máquina:"
echo "sudo yum update -y"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    sudo yum update -y

fi



# 2a. Instalar Docker (Amazon Linux 2)
echo "2. Instalar Docker:"
echo "sudo amazon-linux-extras install docker -y"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    # 2a.1 Instalar Docker (Amazon Linux 2)
    sudo amazon-linux-extras install docker -y

fi



# 3. Instalar Docker compose:
echo "3. Instalar Docker compose:"
echo "sudo mkdir -p /usr/local/lib/docker/cli-plugins"
echo "sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose"
echo "sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    # 3.1 Instalar Docker Compose v2 (prepara directorios de plugins)
    sudo mkdir -p /usr/local/lib/docker/cli-plugins

    # 3.2 Instalar Docker Compose v2 (Copia software)
    sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose

    # 3.3 Instalar Docker Compose v2 (Da los permisos de ejecucion)
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

fi



# 4. Permisos y grupos a usuario ec2
echo "4. Permisos y grupos a usuario ec2:"
echo "sudo usermod -a -G docker ec2-user"
echo "newgrp docker"
echo "sudo systemctl enable --now docker"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    # 4.1 Agregue el ec2-user al grupo docker para que pueda ejecutar comandos de Docker sin usar sudo.
    sudo usermod -a -G docker ec2-user

    # 4.2 Aplicar el nuevo grupo sin reconectar (opcional)
    newgrp docker

    # 4.3 Iniciar Docker
    sudo systemctl enable --now docker

fi



# 5. Pedimos nombre factoria y aplicación
while true; do
    read -p "Introduce el nombre de la factoría: " pf
    if [[ -n "$pf" ]]; then
        break
    fi
    echo "El nombre de la factoría no puede estar vacío."
done
while true; do
    read -p "Introduce el nombre de la aplicación: " pa
    if [[ -n "$pa" ]]; then
        break
    fi
    echo "El nombre de la aplicación no puede estar vacío."
done



# 6. Creación de directorios y permisos
echo "6. Permisos y grupos a usuario ec2:"
echo "sudo mkdir -p /var/opt/$pf/inbox"
echo "sudo chown -R ec2-user:ec2-user /var/opt/$pf/inbox"
echo "sudo mkdir -p /opt/$pf/$pa"
echo "sudo chown -R ec2-user:ec2-user /opt/$pf"
echo "sudo mkdir -p /etc/opt/$pf"
echo "sudo chown -R ec2-user:ec2-user /etc/opt/$pf"
echo "sudo chmod -R 600 /etc/opt/$pf"
echo "sudo mkdir -p /var/db"
echo "sudo chown -R 999:999 /var/db"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    # 6.1 Crea directorio para inbox
    sudo mkdir -p /var/opt/$pf/inbox
    sudo chown -R ec2-user:ec2-user /var/opt/$pf/inbox

    # 6.2 Crea directorio para aplicación
    sudo mkdir -p /opt/$pf/$pa
    sudo chown -R ec2-user:ec2-user /opt/$pf

    # 6.3 Creación de directorio para configuración
    mkdir -p /etc/opt/$pf
    sudo chown -R ec2-user:ec2-user /etc/opt/$pf
    sudo chmod -R 600 /etc/opt/$pf

    # 6.4 Creación de directorio para base de datos
    sudo mkdir -p /var/db
    sudo chown -R 999:999 /var/db

fi



# 7. Subida de software
echo "7. Subida de software"
echo "Ejecute en la máquina de desarrollo:"
echo "tar -czvf /deploy/$pa.tar.gz "
echo "scp /deploy/$pa.tar.gz ec2-user@EC2:/var/opt/$pf/inbox"
read -p "Pulse intro para continuar: " y
if [[ "$y" == "Y" ]]; then
    exit 1
fi



# 8. Descompresion de software
echo "8. Descompresion de software:"
echo "tar -xzvf /var/opt/$pf/inbox/$pa.tar.gz -C /opt/$pf/$pa"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    tar -xzvf /var/opt/$pf/inbox/$pa.tar.gz -C /opt/$pf/$pa

fi




# 9. Configuracion
echo "9. Configuracion:"
echo "sudo touch /etc/opt/$pf/$pa.env"
echo chmod 600 /etc/opt/$pf/$pa.env
echo "sudo nano /etc/opt/$pf/$pa.env"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    # 9.1 Damos permisos al fichero de configuracion
    sudo touch /etc/opt/$pf/$pa.env
    sudo chmod 600 /etc/opt/$pf/$ap.env

    # 9.2 Los editamos
    sudo nano /etc/opt/$pf/$ap.env

fi



# 10. Iniciar docker.
echo "10. Iniciar docker & composer:"
echo "docker compose up -d --build"
echo ""
read -p "Continue? (Y/N): " y
if [[ "$y" == "Y" ]]; then

    docker compose up -d --build

fi

# 10.4 Verificaciones
docker --version
docker compose version
#!/usr/bin/env bash
#---------------------------------------------------------------------
# installpardus.sh
#
# NopCommerce system installer
#
# Script: installpardus.sh
# Version: 1.0.5
# Author: B1gLorD <furytr@yandex.com>
# Description: This script will install all the packages needed to install
# NopCommerce on your server.
# https://docs.nopcommerce.com/en/installation-and-upgrading/installing-nopcommerce/installing-on-linux.html
#
#---------------------------------------------------------------------

AskQuestions() {
	if ! command -v whiptail >/dev/null; then
		echo -n "Installing whiptail... "
		sudo apt-get install whiptail
		echo -e "[${green}DONE${NC}]\n"
	fi

	while [[ ! "$CFG_MYSQL_ROOT_PWD" =~ $RE ]]
	do
		CFG_MYSQL_ROOT_PWD=$(whiptail --title "MySQL" --backtitle "$WT_BACKTITLE" --passwordbox "Please specify a root password" --nocancel 10 50 3>&1 1>&2 2>&3)
	done
}

# Register Microsoft key and feed

wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

sudo dpkg -i packages-microsoft-prod.deb


# Install the .NET Core Runtime
# Update the products available for installation, then install the .NET runtime:

sudo apt-get update

sudo apt-get install apt-transport-https aspnetcore-runtime-3.1

# You may see all installed .Net Core runtimes by the following command:

dotnet --list-runtimes


# Install MySql Server
# Install the MySql server 8.0 version

sudo apt-get install expect mariadb-client libmariadb-dev mariadb-server

# By default, the root password is empty, let's set it
# sudo /usr/bin/mysql_secure_installation

sudo  systemctl enable mariadb.service
sudo  systemctl start mariadb.service
SECURE_MYSQL=$(expect -c "
set timeout 3
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"root password?\"
send \"y\r\"
expect \"New password:\"
send \"$CFG_MYSQL_ROOT_PWD\r\"
expect \"Re-enter new password:\"
send \"$CFG_MYSQL_ROOT_PWD\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")


# Install nginx
# Install the nginx package:

sudo apt-get install nginx

# Run the nginx service:

sudo systemctl start nginx

# and check its status:

#sudo systemctl nginx


# To configure nginx as a reverse proxy to forward requests to your ASP.NET Core app, modify /etc/nginx/sites-available/default. Open it in a text editor and replace the contents with the following:

sudo  cat > /etc/nginx/sites-available/default << EOF
# Default server configuration
#
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name   nopCommerce-430.com;

    location / {
    proxy_pass         http://localhost:5000;
    proxy_http_version 1.1;
    proxy_set_header   Upgrade $http_upgrade;
    proxy_set_header   Connection keep-alive;
    proxy_set_header   Host $host;
    proxy_cache_bypass $http_upgrade;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # SSL configuration
    #
    # listen 443 ssl default_server;
    # listen [::]:443 ssl default_server;
    #
    # Note: You should disable gzip for SSL traffic.
    # See: https://bugs.debian.org/773332
    #
    # Read up on ssl_ciphers to ensure a secure configuration.
    # See: https://bugs.debian.org/765782
    #
    # Self signed certs generated by the ssl-cert package
    # Don't use them in a production server!
    #
    # include snippets/snakeoil.conf;
}
EOF


# Get nopCommerce
# Create a directory

sudo mkdir /var/www/nopCommerce430

# Download and unpack the nopCommerce:

cd /var/www/nopCommerce430

sudo wget https://github.com/nopSolutions/nopCommerce/releases/download/release-4.30/nopCommerce_4.30_NoSource_linux_x64.zip

sudo apt-get install unzip

sudo unzip nopCommerce_4.30_NoSource_linux_x64.zip

# Create couple directories to run nopCommerce:

sudo mkdir bin

sudo mkdir logs

# Change the file permissions

cd ..

sudo chgrp -R nginx nopCommerce430/

sudo chown -R nginx nopCommerce430/


# Create the nopCommerce service
# Create the /etc/systemd/system/nopCommerce430.service file with the following contents:

sudo  cat > /etc/systemd/system/nopCommerce430.service << EOF
[Unit]
Description=Example nopCommerce app running on Pardus

[Service]
WorkingDirectory=/var/www/nopCommerce430
ExecStart=/usr/bin/dotnet /var/www/nopCommerce430/Nop.Web.dll
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=nopCommerce430-example
User=nginx
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

# Start the service

sudo systemctl start nopCommerce430.service

# Restart the nginx server

sudo systemctl restart nginx

# Check the nopCommerce service status

sudo systemctl status nopCommerce430.service
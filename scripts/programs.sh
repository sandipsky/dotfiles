#!/bin/bash

sudo pacman -S dotnet-sdk nodejs-lts-iron npm mysql --noconfirm --needed

npm i -g @angular/cli json-server --prefix=/home/sandip/.local

sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

sudo systemctl enable --now mysqld
# Wait for MySQL to start
sleep 5

# Secure MySQL installation and create user
sudo mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('asd');"
sudo mysql -e "CREATE USER 'sandip'@'localhost' IDENTIFIED BY 'asd';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'sandip'@'localhost' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"


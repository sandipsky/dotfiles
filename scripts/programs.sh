#!/bin/bash

USERNAME=$(logname)
git config --global user.email "sandipshakya75@gmail.com"
git config --global user.name "sandipsky"

sudo pacman -S nodejs-lts-iron npm jdk21-openjdk tomcat10 nginx mysql --noconfirm --needed

npm i -g @angular/cli --prefix=/home/$USERNAME/.local

sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

sudo systemctl enable --now mysqld
sleep 2

sudo mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('Admin@123');"
sudo mysql -e "CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY 'asd';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@'localhost' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"

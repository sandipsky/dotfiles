sudo pacman -S php7 php7-mongodb php7-cgi php7-apache php7-fpm php7-gd php7-pgsql php7-memcache php7-sqlite python-pip dotnet-sdk nodejs npm jdk-openjdk -y


cd ..

chmod 755 composer.phar
sudo cp composer.phar /usr/local/bin/composer
sudo ln -s /usr/bin/php7 /usr/bin/php

pip install django

cd ~
python -m venv env 

yay -S xampp


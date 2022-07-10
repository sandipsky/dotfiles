#!/bin/bash

sudo dpkg --add-architecture i386 
wget -nc https://dl.winehq.org/wine-builds/winehq.key
sudo mv winehq.key /usr/share/keyrings/winehq-archive.key

#sudo apt-key add winehq.key

#change to ubuntu version using
wget -nc https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
sudo mv winehq-jammy.sources /etc/apt/sources.list.d/


sudo apt update
sudo apt install --install-recommends winehq-staging -y

#change to latest dxvk
wget https://github.com/doitsujin/dxvk/releases/download/v1.10.1/dxvk-1.10.1.tar.gz
tar -xf dxvk-1.10.1.tar.gz
cd dxvk-1.10.1
export WINEPREFIX=/home/sandipsky/.wine
./setup_dxvk.sh install
cd ~

sudo apt install libvulkan1 libvulkan-dev libvulkan1:i386 lutris steam -y

rm winehq.key
rm -r dxvk-1.10.1

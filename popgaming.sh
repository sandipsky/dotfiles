#!/bin/bash

sudo dpkg --add-architecture i386 
wget -nc https://dl.winehq.org/wine-builds/winehq.key
sudo mv winehq.key /usr/share/keyrings/winehq-archive.key

sudo apt-key add winehq.key

#change to ubuntu version using
wget -nc https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
sudo mv winehq-jammy.sources /etc/apt/sources.list.d/


sudo apt update
sudo apt install --install-recommends winehq-staging -y

cd ..
cd runtime
wine 1.exe
wine 2.exe
wine 3.exe
wine 4.exe
wine 5.exe
wine 6.exe
wine 7.exe
wine 8.exe
wine 9.exe
wine 10.exe
wine 11.exe
wine 12.exe

#change to latest dxvk
wget https://github.com/doitsujin/dxvk/releases/download/v1.10.2/dxvk-1.10.3.tar.gz
tar -xf dxvk-1.10.3.tar.gz
cd dxvk-1.10.3
export WINEPREFIX=/home/sandipsky/.wine
./setup_dxvk.sh install
cd ~

sudo apt install libvulkan1 libvulkan-dev libvulkan1:i386 lutris steam -y

rm winehq.key
rm -r dxvk-1.10.1

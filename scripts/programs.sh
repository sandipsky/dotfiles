#!/bin/bash

sudo pacman -S dotnet-sdk nodejs-lts-iron npm jdk21-openjdk --noconfirm --needed

yay -S google-chrome visual-studio-code-bin --noconfirm --needed

bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

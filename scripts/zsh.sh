#!/bin/bash

USERNAME=$(logname)

sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions starship --noconfirm --needed
sudo usermod -s /bin/zsh "$USERNAME"
cp .zshrc /home/$USERNAME/.zshrc

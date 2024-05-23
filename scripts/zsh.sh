#!/bin/bash
sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions starship --noconfirm --needed
chsh -s /bin/zsh sandip
cp .zshrc /home/sandip/.zshrc
#!/bin/bash

USERNAME="sandip"

sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions starship --noconfirm --needed
chsh -s /bin/zsh $USERNAME
cp .zshrc /home/$USERNAME/.zshrc

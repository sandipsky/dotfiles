#!/bin/bash

sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

sudo pacman -Syy

sudo pacman -S --needed --noconfirm wine-staging wine-mono wine-gecko lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader lib32-mesa vulkan-intel lib32-vulkan-intel lutris
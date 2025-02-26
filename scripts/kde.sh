sudo pacman -S plasma konsole sddm ark dolphin spectacle gwenview okular kcalc ffmpegthumbs xdg-user-dirs firefox vlc rhythmbox neofetch gvfs-mtp ffmpegthumbnailer sddm -y

sudo pacman -S ttf-liberation noto-fonts-cjk ttf-fira-sans ttf-jetbrains-mono ttf-dejavu noto-fonts noto-fonts-emoji noto-fonts-extra --noconfirm --needed

cd .. #dotfiles
cd scripts
sh aur.sh
sh git.sh
sh ntfs.sh
sh automount.sh
sh battery.sh
sleep 4
sh programs.sh
sh gaming.sh

yay -S google-chrome auto-cpufreq visual-studio-code-bin --noconfirm --needed
sudo auto-cpufreq --install

sudo systemctl enable sddm
reboot
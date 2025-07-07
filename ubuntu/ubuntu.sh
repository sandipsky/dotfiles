#!/usr/bin/env bash

disable_ubuntu_report() {
    ubuntu-report send no
    apt remove ubuntu-report -y
}

remove_appcrash_popup() {
    apt remove apport apport-gtk -y
}

remove_snaps() {
    while [ "$(snap list | wc -l)" -gt 0 ]; do
        for snap in $(snap list | tail -n +2 | cut -d ' ' -f 1); do
            snap remove --purge "$snap" 2> /dev/null
        done
    done

    systemctl stop snapd
    systemctl disable snapd
    systemctl mask snapd
    apt purge snapd -y
    rm -rf /snap /var/lib/snapd
    for userpath in /home/*; do
        rm -rf $userpath/snap
    done
    cat <<-EOF | tee /etc/apt/preferences.d/nosnap.pref
	Package: snapd
	Pin: release a=*
	Pin-Priority: -10
	EOF
}

disable_terminal_ads() {
    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news 2>/dev/null
    pro config set apt_news=false
}

update_system() {
    apt update && apt upgrade -y
}

cleanup() {
    apt autoremove -y
}

gsettings_wrapper() {
    if ! command -v dbus-launch; then
        sudo apt install dbus-x11 -y
    fi
    sudo -Hu $(logname) dbus-launch gsettings "$@"
}

set_fonts() {
	gsettings_wrapper set org.gnome.desktop.interface monospace-font-name "Monospace 10"
}

setup_vanilla_gnome() {
    apt install qgnomeplatform-qt5 -y
    apt install qgnomeplatform-qt6 -y
    apt install gnome-session fonts-cantarell adwaita-icon-theme gnome-backgrounds gnome-tweaks vanilla-gnome-default-settings gnome-shell-extension-manager -y && apt remove ubuntu-session yaru-theme-gnome-shell yaru-theme-gtk yaru-theme-icon yaru-theme-sound -y
    set_fonts
    restore_background
}

restore_background() {
    gsettings_wrapper set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-l.svg'
    gsettings_wrapper set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-l.svg'
}

install_adwgtk3() {    
    wget -O /tmp/adw-gtk3.tar.xz https://github.com/lassekongo83/adw-gtk3/releases/download/v5.10/adw-gtk3v5.10.tar.xz
    tar -xf /tmp/adw-gtk3.tar.xz -C /usr/share/themes/
    if [ "$(gsettings_wrapper get org.gnome.desktop.interface color-scheme | tail -n 1)" == ''\''prefer-dark'\''' ]; then
        gsettings_wrapper set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
        gsettings_wrapper set org.gnome.desktop.interface color-scheme prefer-dark
    else
        gsettings_wrapper set org.gnome.desktop.interface gtk-theme adw-gtk3
    fi
}

install_icons() {
    apt install adwaita-icon-theme -y
}

msg() {
    tput setaf 2
    echo "[*] $1"
    tput sgr0
}

error_msg() {
    tput setaf 1
    echo "[!] $1"
    tput sgr0
}

check_root_user() {
    if [ "$(id -u)" != 0 ]; then
        echo 'Please run the script as root!'
        echo 'We need to do administrative tasks'
        exit
    fi
}

main() {
    check_root_user
    msg 'Updating system'
    update_system
    msg 'Disabling ubuntu report'
    disable_ubuntu_report
    msg 'Removing annoying appcrash popup'
    remove_appcrash_popup
    msg 'Removing terminal ads (if they are enabled)'
    disable_terminal_ads
    msg 'Deleting everything snap related'
    remove_snaps
    msg 'Installing vanilla Gnome session'
    setup_vanilla_gnome
    msg 'Install adw-gtk3'
    install_adwgtk3
    msg 'Installing icons'
    install_icons
    msg 'Cleaning up'
    cleanup

}

(return 2> /dev/null) || main
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

setopt inc_append_history

eval "$(starship init zsh)"
export ANDROID_SDK_ROOT="/home/sandip/AndroidSDK"
export PATH="/home/sandip/.local/bin:$PATH"
export PATH="$PATH:/home/sandip/AndroidSDK/cmdline-tools/latest/bin:/home/sandip/AndroidSDK/emulator:/home/sandip/flutter/bin"

alias update-initramfs="mkinitcpio -P"
alias resolve="prime-run /opt/resolve/bin/resolve"

export QT_QPA_PLATFORM=xcb
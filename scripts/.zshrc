source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

setopt inc_append_history

eval "$(starship init zsh)"
export PATH="/home/sandip/.local/bin:$PATH"

alias update-initramfs="mkinitcpio -P"
alias resolve="prime-run /opt/resolve/bin/resolve"

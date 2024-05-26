source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

setopt inc_append_history

eval "$(starship init zsh)"
export PATH="/home/sandip/.local/bin:$PATH"

alias sudo='sudo '
alias update-grub="grub-mkconfig -o /boot/grub/grub.cfg"
alias update-initramfs="mkinitcpio -P"
alias apt='pacman '
alias install='-S '
alias remove='-Rnsc '

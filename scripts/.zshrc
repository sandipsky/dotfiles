# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# History
HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000
setopt inc_append_history

# Paths & aliases
export PATH=$PATH:~/.local/bin
alias update-initramfs="mkinitcpio -P"
alias update-grub="grub-mkconfig -o /boot/grub/grub.cfg"
alias sudo="sudo "
alias v="vim"

# Starship prompt
eval "$(starship init zsh)"

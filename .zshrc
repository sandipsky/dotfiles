HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
eval "$(starship init zsh)"

export PATH="/home/sandip/.local/bin:$PATH"

#custom aliases
alias python='python3'
alias venv="source /home/sandip/env/bin/activate"
alias update-grub="grub-mkconfig -o /boot/grub/grub.cfg"

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh



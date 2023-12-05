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

if [[ -x /usr/lib/command-not-found ]] ; then
        if (( ! ${+functions[command_not_found_handler]} )) ; then
                function command_not_found_handler {
                        [[ -x /usr/lib/command-not-found ]] || return 1
                        /usr/lib/command-not-found --no-failure-msg -- ${1+"$1"} && :
                }
        fi
fi

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh



# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt notify
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename "${HOME}/.zshrc"

autoload -Uz compinit
compinit
# End of lines added by compinstall

#for starship
eval "$(starship init zsh)"

alias l="ls"
alias la="ls -a"
alias open="xdg-open"

export PATH="$HOME/bin:$PATH"

EDITOR="nvim"


export PATH=$PATH:~/.local/share/jdtls/bin/

export PATH=$PATH:${HOME}/.spicetify

# Export the disl
alias disl="${HOME}/projects/disl/bin/disl.py"
# env variable for disl.py to work without having to specify directory with -d
export DISL_HOME="${HOME}/projects/disl/"


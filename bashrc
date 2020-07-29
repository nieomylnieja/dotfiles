# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# powerline bash with added kubernetes support
# source ~/.bash-powerl first

# autojump
source /usr/share/autojump/autojump.sh

shopt -s expand_aliases

# Set config variables first
GIT_PROMPT_ONLY_IN_REPO=0
# GIT_PROMPT_FETCH_REMOTE_STATUS=0                  # uncomment to avoid fetching remote status
# GIT_PROMPT_IGNORE_SUBMODULES=1                    # uncomment to avoid searching for changed files in submodules
# GIT_PROMPT_WITH_VIRTUAL_ENV=0                     # uncomment to avoid setting virtual environment infos for node/python/conda environments
# GIT_PROMPT_SHOW_UPSTREAM=1                        # uncomment to show upstream tracking branch
# GIT_PROMPT_SHOW_UNTRACKED_FILES=normal            # can be no, normal or all; determines counting of untracked files
# GIT_PROMPT_SHOW_CHANGED_FILES_COUNT=0             # uncomment to avoid printing the number of changed files
# GIT_PROMPT_START=...                              # uncomment for custom prompt start sequence
# GIT_PROMPT_END=...                                # uncomment for custom prompt end sequence
 
# as last entry source the gitprompt script
# GIT_PROMPT_THEME=Custom                           # use custom theme specified in file GIT_PROMPT_THEME_FILE (default ~/.git-prompt-colors.sh)
# GIT_PROMPT_THEME_FILE=~/.git-prompt-colors.sh
# GIT_PROMPT_THEME=Solarized                        # use theme optimized for solarized color scheme
source ~/.dotfiles/bash-git-prompt/gitprompt.sh

# Set VIM prompt
set -o vi

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

export GIT_TERMINAL_PROMPT=1

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

export PATH="$HOME/.local/bin:$PATH"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
alias cd..='cd ..'
alias ll='ls -lah'
alias lls='ls -lah | sort -h -k5'
alias cp="rsync --archive --human-readable --progress --verbose --whole-file"
alias v='vim'
alias open='xdg-open'
alias py='python3'
alias c="xclip -sel clip"

# K8s aliases
alias krestarts='kubectl get pod --sort-by=.status.containerStatuses[0].restartCount'
alias kstarts='kubectl get pod --sort-by=.status.startTime'
alias kstarted='kubectl get pod --sort-by=.status.containerStatuses[0].state.running.startedAt'
alias kpod='kubectl get pod | fzf | head -n1 | awk "{print \$1;}" | tr -d "\n" | c'
alias klog='kubectl get pod | fzf | head -n1 | awk "{print \$1;}" | tr -d "\n" | xargs kubectl logs -f --tail=2000'
alias prodCtx='kubectl config use-context lerta-production'
alias devCtx='kubectl config use-context lerta-dev'

# lerta aliases
alias lertaProductionPass='sops -d ~/lerta/infrastructure/k8s/mongodb/production/passwd.json | grep "admin" | tail -n 1 | awk '"'"'{gsub(/"/, "", $2); print $2}'"'"' | tr -d "\n" | c'
alias lertaStagingPass='sops -d ~/lerta/infrastructure/k8s/mongodb/staging/passwd.enc.json | grep "password" | tail -n 1 | awk '"'"'{gsub(/"/, "", $2); print $2}'"'"' | tr -d "\n" | c'
alias awslogin='$(aws ecr get-login --no-include-email --region us-east-1)'

# studies
alias ppVPN='snx -s hellfire.put.poznan.pl -u mateusz.hawrus@student.put.poznan.pl'

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# pyenv path
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"

# scripts path
export PATH="$HOME/bin:$PATH"

# haskell
eval "$(stack --bash-completion-script stack)"

# kafka
export PATH="$HOME/kafka_2.12-2.5.0/bin:$PATH"

# golang coverage
cover () {
    local t=$(mktemp -t cover)
    go test $COVERFLAGS -coverprofile=$t $@ \
        && go tool cover -func=$t \
        && unlink $t
}

## Completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# kubectl autocomplete
source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
alias k=kubectl
complete -F __start_kubectl k


# create file with ancestor dir structure
mkfileP() { 
	mkdir -p "$(dirname "$1")" || return; touch "$1";
}

# manages dotfiles ~ idea from: https://news.ycombinator.com/item?id=11070797
alias config='/usr/bin/git --git-dir=/home/mateusz/.cfg/ --work-tree=/home/mateusz'

# krew path
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# BASH SHARED SEARCH HISTORY

# Avoid duplicates
HISTCONTROL=ignoredups:erasedups  

# When the shell exits, append to the history file instead of overwriting it
shopt -s histappend

# After each command, append to the history file and reread it
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

# java home
export JAVA_HOME="/usr/lib/jvm/java-1.11.0-openjdk-amd64"

# jq 
get_errors(){
  v=$1
  cat $v | jq .error[].Message | uniq | sort
}

# golang
export GO111MODULE=on
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

# fzf
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color fg:#ebdbb2,bg:#282828,hl:#fabd2f,fg+:#ebdbb2,bg+:#3c3836,hl+:#fabd2f
--color info:#83a598,prompt:#bdae93,spinner:#fabd2f,pointer:#83a598,marker:#fe8019,header:#665c54'

# lerta utils
alias lhttp=$HOME/.dotfiles/scripts/lerta-httpie.sh

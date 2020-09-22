export DOTFILES="$HOME/.dotfiles"

# autojump
source /usr/share/autojump/autojump.sh

# run ssh-agent on every tmux or terminal login
# if this won't be enaugh for managing multiple 
if [ ! -S ~/.ssh/ssh_auth_sock ]; then
  eval `ssh-agent`
  ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
fi
export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
ssh-add -l > /dev/null || ssh-add

# allow aliases
shopt -s expand_aliases

# prompt config
source ~/.dotfiles/prompt.sh

# Set VIM prompt
set -o vi
export EDITOR="vim"

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

export GIT_TERMINAL_PROMPT=1

# local user bins
export PATH="$HOME/.local/bin:$PATH"

# java gui doesn't seet xmonad as a nonparenting app, this is a clean way to inform it about that
# apparently it doesn't solve the problem with newer jdk versions
export _JAVA_AWT_WM_NONREPARENTING=1

# so tmux can use 256 colors
alias tmux='TERM=xterm-256color tmux'

# those fancy rust speeders
alias ls='lsd'
alias du='dust'

# Alias definitions.
alias cd..='cd ..'
alias l='ls -l'
alias la='ls -a'
alias lt='ls --tree'
alias ll='ls -lah'
alias lls='ls -lah | sort -h -k5'
alias cp="rsync --archive --human-readable --progress --verbose --whole-file"
alias v='vim'
alias open='xdg-open'
alias py='python3'
alias c="xclip -sel clip"
# This one helps with the quasi-jsons produced by mongodb...
alias rm_oid="sed -E 's/(.*)(ObjectId\()(.*)(\)(.*))/\1\3\5/'"

# K8s aliases
alias krestarts='kubectl get pod --sort-by=.status.containerStatuses[0].restartCount'
alias kstarts='kubectl get pod --sort-by=.status.startTime'
alias kstarted='kubectl get pod --sort-by=.status.containerStatuses[0].state.running.startedAt'
alias kpod='kubectl get pod | fzf | head -n1 | awk "{print \$1;}" | tr -d "\n" | c'
alias klog='kubectl get pod | fzf | head -n1 | awk "{print \$1;}" | tr -d "\n" | xargs kubectl logs -f --tail=2000'
alias klog-kafka='kubectl get pod -n measurements-kafka | fzf | head -n1 | awk "{print \$1;}" | tr -d "\n" | xargs kubectl logs -f --tail=2000 -n measurements-kafka'
alias prodCtx='kubectl config use-context lerta-production'
alias devCtx='kubectl config use-context lerta-dev'
alias kpf='python ~/lerta/developer-tools/port-forwarder/forwarder.py'
alias kexec='kubectl exec -it'

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
export PATH="$HOME/.dotfiles/scripts:$PATH"

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
source /usr/share/bash-completion/bash_completion

# kubectl autocomplete
source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
alias k=kubectl
# extend completion to work with the alias
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

# fzf config
export FZF_DEFAULT_COMMAND='fd --type f'
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color fg:#88C0D0,hl:#EBCB8B,fg+:#88C0D0,hl+:#EBCB8B,bg+:#434C5E
--color pointer:#BF616A,info:#4C566A,spinner:#4C566A,header:#4C566A,prompt:#B48EAD,marker:#EBCB8B'

# lerta utils
alias lhttp=lerta-httpie.sh
export $(cat "$DOTFILES/secrets.local.env")

# pfetch configuration
export PF_INFO="ascii title os host kernel uptime pkgs memory wm shell editor"

# nord dircolors
test -r "~/.dotfiles/nord-dircolors/src/dir_colors" && eval $(dircolors ~/.dotfiles/nord-dircolors/src/dir_colors)
if [ ! -f ~/.dir_colors ]; then
  ln -s "$DOTFILES/nord_dircolors/src/dir_colors" "~/.dir_colors"
fi

# bat colors
export BAT_THEME="Nord"

# delta diff tool, since we're building it using cargo...
export PATH="$DOTFILES/delta/target/release:$PATH"

# node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# vcpkg completion -- this is temprorary and only for that project
source /home/nieomylnieja/myProjects/graphic-design/lib/vcpkg/scripts/vcpkg_completion.bash

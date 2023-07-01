# Bash shared search history
if [ -f $XDG_CONFIG_HOME/fzf/fzf.bash ]; then
  source $XDG_CONFIG_HOME/fzf/fzf.bash
fi

# Source key bindings like CTR+R and completion.
source ~/.nix-profile/share/fzf/key-bindings.bash
source ~/.nix-profile/share/fzf/completion.bash

# Env variables.
export FZF_DEFAULT_COMMAND='fd --type f'
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color fg:#88C0D0,hl:#EBCB8B,fg+:#88C0D0,hl+:#EBCB8B,bg+:#434C5E
--color pointer:#BF616A,info:#4C566A,spinner:#4C566A,header:#4C566A,prompt:#B48EAD,marker:#EBCB8B'

export FZF_ALT_C_COMMAND='fd --type d'
export FZF_ALT_C_OPTS='--preview "tree -C {} | head -500"'

export FZF_CTRL_T_COMMAND='fd --type f'
export FZF_CTRL_T_OPTS='--preview "bat --style numbers,changes --color=always {} | head -500"'

export FZF_COMPLETION_OPTS='--border --info=inline'
export FZF_COMPLETION_TRIGGER='**'

# Load functions overrides.
source "$DOTFILES/config/fzf/override.sh"

# Load custom functions.
source "$DOTFILES/config/fzf/functions.sh"

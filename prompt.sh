# KUBERNETES PROMPT CONFIGURATION

KUBE_PS1_PREFIX='['
KUBE_PS1_SUFFIX=']'
source ~/.dotfiles/kube-ps1/kube-ps1.sh


# GIT PROMPT CONFIGURATION

# Set config variables first
GIT_PROMPT_ONLY_IN_REPO=0
# GIT_PROMPT_FETCH_REMOTE_STATUS=0                  # uncomment to avoid fetching remote status
# GIT_PROMPT_IGNORE_SUBMODULES=1                    # uncomment to avoid searching for changed files in submodules
# GIT_PROMPT_WITH_VIRTUAL_ENV=0                     # uncomment to avoid setting virtual environment infos for node/python/conda environments
# GIT_PROMPT_SHOW_UPSTREAM=1                        # uncomment to show upstream tracking branch
# GIT_PROMPT_SHOW_UNTRACKED_FILES=normal            # can be no, normal or all; determines counting of untracked files
# GIT_PROMPT_SHOW_CHANGED_FILES_COUNT=0             # uncomment to avoid printing the number of changed files
GIT_PROMPT_START='$(kube_ps1) \[\033[33;1m\]\w\[\033[0m\]'                              # uncomment for custom prompt start sequence
# GIT_PROMPT_END=...                                # uncomment for custom prompt end sequence
 
# as last entry source the gitprompt script
# GIT_PROMPT_THEME=Custom                           # use custom theme specified in file GIT_PROMPT_THEME_FILE (default ~/.git-prompt-colors.sh)
# GIT_PROMPT_THEME_FILE=~/.git-prompt-colors.sh
# GIT_PROMPT_THEME=Solarized                        # use theme optimized for solarized color scheme
source ~/.dotfiles/bash-git-prompt/gitprompt.sh

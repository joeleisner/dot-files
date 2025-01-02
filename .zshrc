# Detect OS
_os() { [[ "$OSTYPE" == ${1}* ]] && echo $2 || echo $3 }
_macos() { _os "darwin" $1 $2 }

# XDG directories
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_RUNTIME_DIR=$(_macos "$(getconf DARWIN_USER_TEMP_DIR)" "/run/user/$UID")

# Set the directory to store zinit and its plugins
ZINIT_HOME="$XDG_DATA_HOME/zinit/zinit.git"

# Download zinit if it's not installed
if [ ! -d "$ZINIT_HOME" ]; then
	mkdir -p "$(dirname $ZINIT_HOME)"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# OS-specific dircolors
DIRCOLOR_BIN=$(_macos "gdircolors" "dircolors")
DIRCOLOR_EXISTS=$(command -v ${DIRCOLOR_BIN})

# Directory colors
if [ -x "$DIRCOLOR_EXISTS" ]; then
	zinit ice atclone"$DIRCOLOR_BIN -b > dircolors.zsh" \
		atpull'%atclone' pick"dircolors.zsh" nocompile'!' \
		atload'zstyle ":completion:*" list-colors "${(s.:.)LS_COLORS}"'
	zinit light trapd00r/LS_COLORS
fi

# Syntax highlighting, autosuggestions, & completions
zinit wait lucid light-mode for \
	atinit"zicompinit; zicdreplay" \
		zdharma-continuum/fast-syntax-highlighting \
	atload"_zsh_autosuggest_start" \
		zsh-users/zsh-autosuggestions \
	blockf atpull'zinit creinstall -q .' \
		zsh-users/zsh-completions

# History substring search
_history_substring_search_config() {
	bindkey '^[[A' history-substring-search-up
	bindkey '^[[B' history-substring-search-down
}
zinit ice wait atload'_history_substring_search_config' silent
zinit light 'zsh-users/zsh-history-substring-search'

# Use fzf for auto-completions
FZF_EXISTS=$(command -v fzf)
[[ -x "$FZF_EXISTS" ]] && zinit light Aloxaf/fzf-tab

# NVM
_nvm_config() {
	export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME"/npm/npmrc
	export NVM_DIR="$XDG_DATA_HOME/nvm"
	export NVM_COMPLETION=true
}
zinit ice wait atinit'_nvm_config' silent
zinit light lukechilds/zsh-nvm

# Take
zinit light amyreese/zsh-take

# Keybindings
bindkey -e # Emacs keybindings
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History enhancements
HISTSIZE=5000
export HISTFILE="$XDG_STATE_HOME"/zsh/history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# ls command
LS_BIN=$(_macos "gls" "ls")
LS_EXISTS=$(command -v ${LS_BIN})

# Completion styling
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME"/zsh/zcompcache # Change zcompcache directory
zstyle ':completion:*' matcher-list m:{a-z}={A-Za-z} # Case-insensitive
if [ -x "$FZF_EXISTS" ]; then
	zstyle ':completion:*' menu no
	zstyle ':fzf-tab:complete:cd:*' fzf-preview '${LS_BIN} --color=always --group-directories-first $realpath' # Directory previews in fzf
fi

# Change zcompdump cache location
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-"$ZSH_VERSION"

# Docker
export DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker

# Less history
export LESSHISTFILE="$XDG_STATE_HOME"/less/history

# Aliases
alias ..="cd .." # Move up a directory
[[ -x "$(command -v bat)" ]] && alias cat="bat --theme=Dracula" # bat > cat

if [ -x "$LS_EXISTS" ]; then
	alias ls="$LS_BIN --color --group-directories-first" # ls colors & dirs first
else
	alias ls="ls --color"
fi

[[ -x "$(command -v prettyping)" ]] && alias ping="prettyping" # prettyping > ping
alias cp="cp -iv" # Safe cp
alias mv="mv -iv" # Safe mv
alias mkcd="take" # Create & change directoriesx
[[ -x "$(command -v nvim)" ]] && alias vim="nvim" # neovim > vim
[[ -x "$(command -v yt-dlp)" ]] && alias ytdl="yt-dlp" # yt-dlp shorthand
[[ -x "$(command -v gdate)" ]] && alias date="gdate" # gdate > date

# Shell integrations
[[ -x "$FZF_EXISTS" ]] && eval "$(fzf --zsh)"
[[ -x "$(command -v zoxide)" ]] && eval "$(zoxide init --cmd cd zsh)" # z > cd
[[ -x "$(command -v brew)" ]] && eval "$(brew shellenv)"

# Load ZSH completions
if [[ ":$FPATH:" != *":/Users/joel/.config/zsh/completions:"* ]];
	then export FPATH="/Users/joel/.config/zsh/completions:$FPATH";
fi

# Load the starship prompt
eval "$(starship init zsh)"
# ---- Antigen ----

# The location of Antigen
ANTIGEN_LOCATION=/usr/share/zsh-antigen

# Source Antigen
source $ANTIGEN_LOCATION

# Tell Antigen to use Oh-My-ZSH
antigen use oh-my-zsh

# Have Antigen grab the following bundles
antigen bundles <<EOBUNDLES
composer
deno
docker
git
node
npm
sudo
ubuntu
Cloudstek/zsh-plugin-appup
lukechilds/zsh-nvm
qianxinfeng/zsh-vscode
zdharma-continuum/fast-syntax-highlighting
zsh-users/zsh-autosuggestions
zsh-users/zsh-completions
zsh-users/zsh-history-substring-search
EOBUNDLES

# Have Antigen apply all bundles/theme
antigen apply

# Enable Antigen logging
ANTIGEN_LOG=$HOME/.antigen/antigen.log

# ---- Aliases ----

# Move up a directory
alias ..="cd .."

# Override cat with bat
alias cat="batcat --theme=Dracula"

# Automatically setup/use ls colors
alias ls="ls -h --color=auto --group-directories-first"

# Override ping with prettyping
alias ping="prettyping"

# Safer copy
alias cp="cp -iv"

# Safer move
alias mv="mv -iv"

# Open files/directories with Explorer (WSL)
alias open="explorer.exe $@"

# Create and change directories
alias mkcd="take"

# Use Neovim
alias vim="nvim"

# ---- Exports ----

# Allows mouse scrolling in `less`
export LESS="--mouse --wheel-lines=3 -R"

# ---- Functions ----

# The path (from home) to the development directory
DEVELOPMENT_DIR=development

# Go to a development directory
function _gotodev() {
    cd $HOME/$DEVELOPMENT_DIR/$([ -z "$2" ] && echo $1 || echo $1/$2)
}

# Create shortcuts to development directories
function dev() {
    case "$1" in
        *)
            _gotodev $@
    esac
}

# ---- Path ----

# Define custom paths...
CUSTOM_PATHS=(
    # Custom home binaries
    $HOME/.bin
    # Cargo (Rust package manager)
    $HOME/.cargo
    # Composer (PHP package manager)
    $HOME/.composer/vendor
    # Deno (JS runtime)
    $HOME/.deno/bin
    # Local home binaries
    $HOME/.local/bin
    # PNPM (npm alternative)
    $HOME/.local/share/pnpm
)
# ... and add them to the user's path
foreach CUSTOM_PATH in $CUSTOM_PATHS ; path+=$CUSTOM_PATH ; end

# ---- Theme ----

# Start the Starship prompt
eval $(starship init zsh)

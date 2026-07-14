# Source global definitions if they exist
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Automatically loop through + source modular files
if [ -d "$HOME/.config/bash/bashrc.d" ]; then
    for file in "$HOME/.config/bash/bashrc.d"/*; do
        [ -f "$file" ] && . "$file"
    done
fi

#!/usr/bin/env bash
# Symlink dotfiles into $HOME (backs up existing files to *.bak)
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
link() { [ -e "$2" ] && [ ! -L "$2" ] && mv "$2" "$2.bak"; ln -sfn "$1" "$2"; echo "linked $2"; }
link "$DIR/shell/.bashrc"      ~/.bashrc
link "$DIR/shell/.profile"     ~/.profile
link "$DIR/shell/.bash_logout" ~/.bash_logout

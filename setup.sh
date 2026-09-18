#!/bin/bash

# =============================================================================
#  Dotfiles Setup Script
#  Usage: ./setup.sh [--local]
# =============================================================================

REPO_URL="https://github.com/hemanithin/dotfiles"
TARGET_DIR="${TARGET_DIR:-$HOME/dotfiles}"
BRANCH="linux"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

success() {
    echo -e "${GREEN}[DONE]${NC} $1"
}

# Check if running for local user only (default: auto-detect or if --local/--user flag passed)
LOCAL_USER_ONLY=false

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --local|--user|--user-only)
                LOCAL_USER_ONLY=true
                ;;
            --force-sudo)
                LOCAL_USER_ONLY=false
                ;;
        esac
    done

    # Auto-detect if sudo is not available without password
    if ! $LOCAL_USER_ONLY; then
        if ! sudo -n true 2>/dev/null; then
            log "Passwordless sudo not available. Defaulting to local user mode."
            LOCAL_USER_ONLY=true
        fi
    fi
}

# -----------------------------------------------------------------------------
# Main Execution Function
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    # Determine script location if running from within repo
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    if [ -f "$SCRIPT_DIR/vim_dotfile/vim" ]; then
        TARGET_DIR="$SCRIPT_DIR"
    fi

    # 1. Pull/Clone Repo (if not already running from inside it)
    log "Checking dotfiles repository..."

    if [ -d "$TARGET_DIR" ]; then
        log "Directory $TARGET_DIR exists."
        if [ "$SCRIPT_DIR" != "$TARGET_DIR" ]; then
            if cd "$TARGET_DIR" 2>/dev/null; then
                if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                    log "Pulling latest changes..."
                    git pull origin "$BRANCH" || warn "Git pull failed, using existing files."
                fi
            fi
        fi
    else
        log "Cloning $REPO_URL (branch: $BRANCH)..."
        git clone -b "$BRANCH" "$REPO_URL" "$TARGET_DIR" || { echo "Git clone failed"; exit 1; }
    fi

    success "Dotfiles source ready at $TARGET_DIR"

    # 2. OS Detection
    log "Detecting OS..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        DISTRO_LIKE=$ID_LIKE
    else
        echo "Error: /etc/os-release not found. Unknown OS."
        exit 1
    fi

    log "OS: $OS"

    # 3. Package & Plugin Installation (if not local user only)
    if [ "$LOCAL_USER_ONLY" = true ]; then
        log "Local user mode: Skipping system package installation."
    else
        install_packages
    fi

    # 4. Common Setup (Vim, Copy)
    # --- Vim ---
    log "Setting up Vim configuration for user $(whoami)..."
    if [ -f "$TARGET_DIR/vim_dotfile/vim" ]; then
        cp -f "$TARGET_DIR/vim_dotfile/vim" "$HOME/.vimrc"
        success "Vim setup complete (~/.vimrc)"
    else
        warn "Vim config not found in $TARGET_DIR/vim_dotfile/vim"
    fi

    # --- Copy Utility ---
    log "Setting up Copy utilities in $HOME/.local/bin..."
    mkdir -p "$HOME/.local/bin"

    if [ -f "$TARGET_DIR/copy/copy" ]; then
        cp -f "$TARGET_DIR/copy/copy" "$HOME/.local/bin/copy"
        chmod +x "$HOME/.local/bin/copy"
        success "Installed $HOME/.local/bin/copy"
    fi

    if [ -f "$TARGET_DIR/copy/copy_ssh" ]; then
        cp -f "$TARGET_DIR/copy/copy_ssh" "$HOME/.local/bin/copy_ssh"
        chmod +x "$HOME/.local/bin/copy_ssh"
        success "Installed $HOME/.local/bin/copy_ssh"
    fi

    # Ensure ~/.local/bin is in PATH for user's profile
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # 5. OS Specific Setup (Zsh & Aliases)
    case "$OS" in
        kali)
            setup_zsh "kali"
            ;;
        debian|ubuntu|pop|mint)
            setup_zsh "debian"
            ;;
        fedora|arch|manjaro)
            log "Skipping Zsh setup for $OS as requested."
            ;;
        *)
            # Default to debian configuration if distro is debian-like
            if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
                setup_zsh "debian"
            else
                log "Skipping Zsh setup for unsupported OS ($OS)."
            fi
            ;;
    esac

    # 6. Bash aliases integration
    setup_bash_aliases

    success "Setup complete for user $(whoami)!"
}

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

install_packages() {
    log "Installing packages for $OS..."

    case "$OS" in
        kali)
            sudo apt update
            sudo apt install -y zsh vim git curl
            sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting fzf command-not-found
            ;;
        debian|ubuntu|pop|mint)
            sudo apt update
            sudo apt install -y zsh vim git curl
            sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting fzf command-not-found || echo "Some plugins might not be in apt, skipping..."
            ;;
        fedora)
            sudo dnf check-update
            sudo dnf install -y vim git curl util-linux-user
            ;;
        arch|manjaro)
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm vim git curl
            ;;
        *)
            echo "Unsupported OS: $OS"
            ;;
    esac
}

setup_zsh() {
    local SOURCE_DIR="$1"
    log "Setting up Zsh configuration for user $(whoami) from $SOURCE_DIR..."

    if [ -f "$TARGET_DIR/zshrc_dotfiles/$SOURCE_DIR/.zshrc" ]; then
        cp -f "$TARGET_DIR/zshrc_dotfiles/$SOURCE_DIR/.zshrc" "$HOME/.zshrc"
        success "Copied ~/.zshrc"
    fi

    if [ -f "$TARGET_DIR/zshrc_dotfiles/$SOURCE_DIR/.zsh_aliases" ]; then
        cp -f "$TARGET_DIR/zshrc_dotfiles/$SOURCE_DIR/.zsh_aliases" "$HOME/.zsh_aliases"
        success "Copied ~/.zsh_aliases"
    fi

    # Handle shell change if zsh is installed
    if command -v zsh >/dev/null 2>&1; then
        ZSH_PATH="$(command -v zsh)"
        if [ "$SHELL" != "$ZSH_PATH" ]; then
            if [ "$LOCAL_USER_ONLY" = true ]; then
                log "zsh is installed ($ZSH_PATH). To set as default shell, run: chsh -s $ZSH_PATH"
            else
                log "Changing default shell to zsh..."
                sudo chsh -s "$ZSH_PATH" "$USER"
                success "Default shell changed to zsh"
            fi
        fi
    else
        log "zsh is not installed. Configurations saved for when zsh is used."
    fi
}

setup_bash_aliases() {
    log "Configuring bash alias integration for user $(whoami)..."
    local BASH_ALIASES="$HOME/.bash_aliases"

    # Ensure ~/.bash_aliases sources ~/.zsh_aliases so aliases work in bash too
    local SOURCE_LINE='[ -f "$HOME/.zsh_aliases" ] && . "$HOME/.zsh_aliases"'

    if [ -f "$BASH_ALIASES" ]; then
        if ! grep -Fq '.zsh_aliases' "$BASH_ALIASES"; then
            echo "" >> "$BASH_ALIASES"
            echo "# Source shared zsh/shell aliases" >> "$BASH_ALIASES"
            echo "$SOURCE_LINE" >> "$BASH_ALIASES"
            success "Linked ~/.zsh_aliases into existing ~/.bash_aliases"
        else
            log "~/.zsh_aliases already sourced in ~/.bash_aliases"
        fi
    else
        cat << 'EOF' > "$BASH_ALIASES"
# ~/.bash_aliases - Local user aliases
# Source shared aliases from .zsh_aliases
if [ -f "$HOME/.zsh_aliases" ]; then
    . "$HOME/.zsh_aliases"
fi
EOF
        success "Created ~/.bash_aliases sourcing ~/.zsh_aliases"
    fi
}

# -----------------------------------------------------------------------------
# Execution
# -----------------------------------------------------------------------------
main "$@"

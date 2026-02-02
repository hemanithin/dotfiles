#!/bin/bash

REPO_URL="https://github.com/hemanithin/dotfiles"
TARGET_DIR="$HOME/dotfiles"
BRANCH="linux"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

success() {
    echo -e "${GREEN}[DONE]${NC} $1"
}

# -----------------------------------------------------------------------------
# 1. Pull/Clone Repo
# -----------------------------------------------------------------------------
log "Checking dotfiles repository..."

if [ -d "$TARGET_DIR" ]; then
    log "Directory $TARGET_DIR exists. Pulling latest changes..."
    cd "$TARGET_DIR" || exit
    # Check if inside a git repo
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git pull origin "$BRANCH"
    else
        echo "Error: $TARGET_DIR exists but is not a git repository."
        exit 1
    fi
else
    log "Cloning $REPO_URL (branch: $BRANCH)..."
    git clone -b "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

success "Repository is ready in $TARGET_DIR"


# -----------------------------------------------------------------------------
# 2. OS Detection
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 3. Package & Plugin Installation
# -----------------------------------------------------------------------------
install_packages() {
    log "Installing packages for $OS..."
    
    case "$OS" in
        kali)
            sudo apt update
            sudo apt install -y zsh vim git curl
            # Install Zsh plugins (Kali/Debian usually have these in repos)
            sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting fzf command-not-found
            ;;
        debian|ubuntu|pop|mint) # Debian based
            sudo apt update
            sudo apt install -y zsh vim git curl
            # Try to install zsh plugins if available, otherwise might need manual install
            # Ubuntu/Debian repos often have these.
            sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting fzf command-not-found || echo "Some plugins might not be in apt, skipping..."
            ;;
        fedora)
            sudo dnf check-update
            sudo dnf install -y vim git curl util-linux-user
            # Skipping Zsh installation as requested for non-Debian/Kali
            ;;
        arch|manjaro)
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm vim git curl
           # Skipping Zsh installation as requested for non-Debian/Kali
            ;;
        *)
            echo "Unsupported OS: $OS"
            ;;
    esac
}

install_packages

# -----------------------------------------------------------------------------
# 4. Common Setup (Vim, Copy)
# -----------------------------------------------------------------------------

# --- Vim ---
log "Setting up Vim..."
ln -sf "$TARGET_DIR/vim_dotfile/vim" "$HOME/.vimrc"
success "Vim setup complete"

# --- Copy Utility ---
log "Setting up Copy Utility..."
mkdir -p "$HOME/.local/bin"

# Original Copy (for WSL/Local)
cp "$TARGET_DIR/copy/copy" "$HOME/.local/bin/copy"
chmod +x "$HOME/.local/bin/copy"

# Copy SSH (OSC 52)
cp "$TARGET_DIR/copy/copy_ssh" "$HOME/.local/bin/copy_ssh"
chmod +x "$HOME/.local/bin/copy_ssh"

success "Copy utilities installed to ~/.local/bin" 
echo "Ensure ~/.local/bin is in your PATH."


# -----------------------------------------------------------------------------
# 5. OS Specific Setup (Zsh)
# -----------------------------------------------------------------------------

setup_zsh() {
    local SOURCE_DIR="$1"
    log "Setting up Zsh from $SOURCE_DIR..."
    
    ln -sf "$TARGET_DIR/zshrc_dotfiles/$SOURCE_DIR/.zshrc" "$HOME/.zshrc"
    ln -sf "$TARGET_DIR/zshrc_dotfiles/$SOURCE_DIR/.zsh_aliases" "$HOME/.zsh_aliases"
    
    # Change shell to zsh if not already
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "Changing default shell to zsh..."
        chsh -s "$(which zsh)"
    fi
}

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
        log "Skipping Zsh setup for unknown OS."
        ;;
esac

success "Setup Complete!"

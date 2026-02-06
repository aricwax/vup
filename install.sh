#!/usr/bin/env bash
# install.sh - Install vup virtual environment manager
#
# This script installs vup for the current user by:
#   1. Copying vup-core to ~/.local/bin/
#   2. Copying vup.sh to ~/.local/share/vup/
#   3. Adding shell integration to the appropriate config file
#
# Usage: ./install.sh
#
# The script will prompt before modifying shell configuration files.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_BIN="$HOME/.local/bin"
INSTALL_SHARE="$HOME/.local/share/vup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source files
VUP_CORE="$SCRIPT_DIR/vup-core"
VUP_SH="$SCRIPT_DIR/vup.sh"

# ============================================================================
# Helper functions
# ============================================================================

info() {
    echo -e "${BLUE}==>${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

# ============================================================================
# Pre-flight checks
# ============================================================================

info "vup installation script"
echo ""

# Check that source files exist
if [ ! -f "$VUP_CORE" ]; then
    error "vup-core not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$VUP_SH" ]; then
    error "vup.sh not found in $SCRIPT_DIR"
    exit 1
fi

# ============================================================================
# Install files
# ============================================================================

info "Installing vup files..."

# Create directories if they don't exist
mkdir -p "$INSTALL_BIN"
mkdir -p "$INSTALL_SHARE"

# Copy vup-core to ~/.local/bin/
cp "$VUP_CORE" "$INSTALL_BIN/vup-core"
chmod +x "$INSTALL_BIN/vup-core"
success "Installed vup-core to $INSTALL_BIN/vup-core"

# Copy vup.sh to ~/.local/share/vup/
cp "$VUP_SH" "$INSTALL_SHARE/vup.sh"
success "Installed vup.sh to $INSTALL_SHARE/vup.sh"

# ============================================================================
# Shell integration
# ============================================================================

echo ""
info "Setting up shell integration..."

# Detect user's shell
USER_SHELL=$(basename "$SHELL")

# Determine config file based on shell
case "$USER_SHELL" in
    bash)
        CONFIG_FILE="$HOME/.bashrc"
        SHELL_NAME="Bash"
        ;;
    zsh)
        CONFIG_FILE="$HOME/.zshrc"
        SHELL_NAME="Zsh"
        ;;
    *)
        CONFIG_FILE="$HOME/.profile"
        SHELL_NAME="POSIX shell"
        warning "Using ~/.profile for shell integration (shell: $USER_SHELL)"
        ;;
esac

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    warning "Config file $CONFIG_FILE does not exist. Creating it."
    touch "$CONFIG_FILE"
fi

# Check if vup is already configured
if grep -q "vup.sh" "$CONFIG_FILE" 2>/dev/null; then
    warning "vup appears to be already configured in $CONFIG_FILE"
    echo "    Skipping shell configuration."
else
    # Check if PATH includes ~/.local/bin
    need_path=false
    if ! echo "$PATH" | grep -q "$INSTALL_BIN"; then
        need_path=true
    fi

    # Ask user for confirmation
    echo ""
    echo "vup needs to add the following lines to $CONFIG_FILE:"
    echo ""
    if [ "$need_path" = true ]; then
        echo "    # Add ~/.local/bin to PATH"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi
    echo "    # vup - Python virtual environment manager"
    echo "    export BASE_PS1='\$ '"
    echo "    export VIRTUAL_ENV_DISABLE_PROMPT=1"
    echo "    . $INSTALL_SHARE/vup.sh"
    echo ""
    read -p "Add these lines to $CONFIG_FILE? [Y/n] " -r response

    if [ -z "$response" ] || [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        # Add configuration to shell config
        if [ "$need_path" = true ]; then
            cat >> "$CONFIG_FILE" << EOF

# Add ~/.local/bin to PATH
export PATH="\$HOME/.local/bin:\$PATH"

# vup - Python virtual environment manager
export BASE_PS1='\$ '
export VIRTUAL_ENV_DISABLE_PROMPT=1
. $INSTALL_SHARE/vup.sh
EOF
        else
            cat >> "$CONFIG_FILE" << EOF

# vup - Python virtual environment manager
export BASE_PS1='\$ '
export VIRTUAL_ENV_DISABLE_PROMPT=1
. $INSTALL_SHARE/vup.sh
EOF
        fi
        success "Added vup configuration to $CONFIG_FILE"
    else
        echo "Skipped shell configuration."
        echo ""
        warning "You'll need to manually add these lines to your shell config:"
        echo ""
        if [ "$need_path" = true ]; then
            echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        echo "    export BASE_PS1='\$ '"
        echo "    export VIRTUAL_ENV_DISABLE_PROMPT=1"
        echo "    . $INSTALL_SHARE/vup.sh"
    fi
fi

# ============================================================================
# Success message
# ============================================================================

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To start using vup:"
echo "  1. Restart your shell or run: source $CONFIG_FILE"
echo "  2. Try: vup help"
echo ""
echo "Quick start:"
echo "  vup init              # Create .venv/ directory"
echo "  vup new myenv         # Create and activate a venv"
echo "  vup ls                # List available venvs"
echo "  vup off               # Deactivate current venv"
echo ""
echo "For more information, see: https://github.com/your-repo/vup"
echo ""

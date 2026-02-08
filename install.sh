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

# Check Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
    error "python3 is required but not found"
    echo "Install Python 3.3+ before continuing."
    exit 1
fi

# Check Python venv module can create virtual environments.
# On Debian/Ubuntu, the venv module is present but venv creation fails without
# the python3-venv package, which provides ensurepip.
PYTHON_VERSION=$(python3 --version 2>&1)
if python3 -c "import ensurepip" 2>/dev/null; then
    success "Python venv support found ($PYTHON_VERSION)"
else
    error "Python venv module cannot create virtual environments ($PYTHON_VERSION)"
    echo ""
    echo "The venv module is installed but missing ensurepip support."
    echo "On Debian/Ubuntu systems, install it with:"
    echo "  sudo apt install python3-venv"
    echo ""
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

# Detect available shell configuration files
declare -a SHELL_CONFIGS
declare -a SHELL_NAMES
SHELL_INDEX=0

if [ -f "$HOME/.bashrc" ] || [ "$SHELL" = "bash" ] || [ "$SHELL" = "/bin/bash" ]; then
    SHELL_INDEX=$((SHELL_INDEX + 1))
    SHELL_CONFIGS[$SHELL_INDEX]="$HOME/.bashrc"
    SHELL_NAMES[$SHELL_INDEX]="bash"
fi

if [ -f "$HOME/.zshrc" ] || [ "$SHELL" = "zsh" ] || [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_INDEX=$((SHELL_INDEX + 1))
    SHELL_CONFIGS[$SHELL_INDEX]="$HOME/.zshrc"
    SHELL_NAMES[$SHELL_INDEX]="zsh"
fi

if [ -f "$HOME/.profile" ]; then
    SHELL_INDEX=$((SHELL_INDEX + 1))
    SHELL_CONFIGS[$SHELL_INDEX]="$HOME/.profile"
    SHELL_NAMES[$SHELL_INDEX]="sh/other"
fi

# If no shells detected, fall back to current shell
if [ ${#SHELL_CONFIGS[@]} -eq 0 ]; then
    USER_SHELL=$(basename "$SHELL")
    case "$USER_SHELL" in
        bash) CONFIG_FILE="$HOME/.bashrc" ;;
        zsh) CONFIG_FILE="$HOME/.zshrc" ;;
        *) CONFIG_FILE="$HOME/.profile" ;;
    esac
    warning "No shell config files detected. Will create $CONFIG_FILE"
    touch "$CONFIG_FILE"
    SHELL_CONFIGS[1]="$CONFIG_FILE"
    SHELL_NAMES[1]="$USER_SHELL"
fi

# Show detected shells and prompt for selection
echo ""
echo "Detected shell configuration files:"
for i in "${!SHELL_CONFIGS[@]}"; do
    echo "  $i) ${SHELL_NAMES[$i]}"$'\t'"${SHELL_CONFIGS[$i]}"
done
echo ""
echo "All shells will be configured by default."
read -p "Press Enter to configure all, or enter numbers to select (e.g., '1 3'): " -r selection

# Parse selection
SELECTED_CONFIGS=()
if [ -z "$selection" ] || [ "$selection" = "y" ] || [ "$selection" = "Y" ] || [ "$selection" = "all" ]; then
    # Configure all shells
    SELECTED_CONFIGS=("${SHELL_CONFIGS[@]}")
elif [ "$selection" = "none" ] || [ "$selection" = "n" ] || [ "$selection" = "N" ]; then
    # Configure none
    echo ""
    warning "Skipping shell configuration."
    echo "You'll need to manually add vup to your shell config. See INSTALL.md for details."
    echo ""
    exit 0
else
    # Parse space or comma-separated numbers
    for num in ${selection//,/ }; do
        if [ -n "${SHELL_CONFIGS[$num]}" ]; then
            SELECTED_CONFIGS+=("${SHELL_CONFIGS[$num]}")
        else
            warning "Invalid selection: $num (skipping)"
        fi
    done
    if [ ${#SELECTED_CONFIGS[@]} -eq 0 ]; then
        error "No valid shells selected. Exiting."
        exit 1
    fi
fi

# Check if PATH includes ~/.local/bin
need_path=false
if ! echo "$PATH" | grep -q "$INSTALL_BIN"; then
    need_path=true
fi

# Configure each selected shell
echo ""
for CONFIG_FILE in "${SELECTED_CONFIGS[@]}"; do
    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        info "Creating $CONFIG_FILE"
        touch "$CONFIG_FILE"
    fi

    # Check if vup is already configured
    if grep -q "vup.sh" "$CONFIG_FILE" 2>/dev/null; then
        warning "vup appears to be already configured in $CONFIG_FILE (skipping)"
        continue
    fi

    # Add configuration to shell config
    if [ "$need_path" = true ]; then
        cat >> "$CONFIG_FILE" << EOF

# Add ~/.local/bin to PATH
export PATH="\$HOME/.local/bin:\$PATH"

# vup - Python virtual environment manager
export VIRTUAL_ENV_DISABLE_PROMPT=1
# Capture user's original prompt (set in this config file) for use by vup
PS1_BASE="\${PS1_BASE:-\${PS1:-\\\$ }}"
export PS1_BASE
. $INSTALL_SHARE/vup.sh
# vup is now ready to use. Add any vup commands below this line.
EOF
    else
        cat >> "$CONFIG_FILE" << EOF

# vup - Python virtual environment manager
export VIRTUAL_ENV_DISABLE_PROMPT=1
# Capture user's original prompt (set in this config file) for use by vup
PS1_BASE="\${PS1_BASE:-\${PS1:-\\\$ }}"
export PS1_BASE
. $INSTALL_SHARE/vup.sh
# vup is now ready to use. Add any vup commands below this line.
EOF
    fi
    success "Added vup configuration to $CONFIG_FILE"
done

# ============================================================================
# Success message
# ============================================================================

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To start using vup:"
echo "  1. Restart your shell (or run 'source <config_file>')"
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

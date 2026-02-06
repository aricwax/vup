#!/usr/bin/env bash
# uninstall.sh - Uninstall vup virtual environment manager
#
# This script removes vup by:
#   1. Removing vup-core from ~/.local/bin/
#   2. Removing vup.sh from ~/.local/share/vup/
#   3. Removing shell integration from config files (optional)
#
# Usage: ./uninstall.sh
#
# Note: This does NOT remove your virtual environments (.venv/ directories).
# Those must be removed manually if desired.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_BIN="$HOME/.local/bin/vup-core"
INSTALL_SHARE="$HOME/.local/share/vup"

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
# Uninstall
# ============================================================================

info "vup uninstallation script"
echo ""

REMOVED_SOMETHING=false

# Remove vup-core
if [ -f "$INSTALL_BIN" ]; then
    rm "$INSTALL_BIN"
    success "Removed $INSTALL_BIN"
    REMOVED_SOMETHING=true
else
    warning "vup-core not found at $INSTALL_BIN"
fi

# Remove vup.sh and directory
if [ -d "$INSTALL_SHARE" ]; then
    rm -rf "$INSTALL_SHARE"
    success "Removed $INSTALL_SHARE"
    REMOVED_SOMETHING=true
else
    warning "vup.sh not found at $INSTALL_SHARE"
fi

# ============================================================================
# Shell config cleanup
# ============================================================================

echo ""
info "Checking shell configuration files..."

# Check common config files
CONFIG_FILES=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
FOUND_CONFIG=false

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ] && grep -q "vup.sh" "$config" 2>/dev/null; then
        FOUND_CONFIG=true
        echo ""
        warning "Found vup configuration in $config"
        read -p "Remove vup lines from $config? [y/N] " -r response

        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            # Create backup
            cp "$config" "$config.vup-backup"

            # Remove vup lines (the comment and the 3 lines after it)
            sed -i '/# vup - Python virtual environment manager/,+3d' "$config"

            success "Removed vup configuration from $config"
            echo "    Backup saved to $config.vup-backup"
            REMOVED_SOMETHING=true
        else
            echo "Skipped $config - you'll need to remove the vup lines manually"
        fi
    fi
done

if ! $FOUND_CONFIG; then
    info "No vup configuration found in shell config files"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
if $REMOVED_SOMETHING; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Uninstallation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Note: Your virtual environments (.venv/ directories) were not removed."
    echo "      Remove them manually if you no longer need them."
    echo ""
    echo "To complete uninstallation, restart your shell."
else
    warning "vup does not appear to be installed"
fi
echo ""

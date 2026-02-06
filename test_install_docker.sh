#!/usr/bin/env bash
# Test vup installation in a clean Docker container

set -e

echo "Testing vup installation in Ubuntu 22.04 container..."
echo ""

cat << 'SCRIPT_EOF' | docker run --rm -i -v "$PWD:/vup" -w /vup ubuntu:22.04 bash
set -e

# Install prerequisites
echo "Installing prerequisites..."
apt-get update -qq
apt-get install -y -qq python3 python3-venv git > /dev/null

# Run installer (press Enter to accept defaults)
echo "Running install.sh..."
echo "" | ./install.sh

# Verify files were installed
echo ""
echo "Verifying installation..."
ls -lh ~/.local/bin/vup-core
ls -lh ~/.local/share/vup/vup.sh

# Check if shell config was updated
if grep -q "vup.sh" ~/.bashrc; then
    echo "✓ Shell config updated"
else
    echo "✗ Shell config not updated"
    exit 1
fi

# Test vup help (set PS1 so .bashrc doesn't exit early)
echo ""
echo "Testing vup command..."
export PS1='$ '
source ~/.bashrc
vup help | head -5

echo ""
echo "✓ Installation test passed!"
SCRIPT_EOF

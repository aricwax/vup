# Installation Guide

## Prerequisites

- Python 3.3+ (for `venv` module)
- A POSIX-compliant shell (bash, zsh, dash, or sh)
- Standard Unix tools (mkdir, cp, chmod, grep, sed)

## Quick Install (User)

The simplest way to install vup for your user account:

```bash
git clone https://github.com/aricwax/vup.git
cd vup
./install.sh
```

The install script will:
1. Copy `vup-core` to `~/.local/bin/`
2. Copy `vup.sh` to `~/.local/share/vup/`
3. Detect all your shell configs (`.bashrc`, `.zshrc`, `.profile`)
4. Prompt you to select which shells to configure (defaults to all)
5. Add PATH to shell configs if needed

### Multi-Shell Configuration

The installer detects and offers to configure multiple shells:

```
Detected shell configuration files:
  1) bash      ~/.bashrc
  2) zsh       ~/.zshrc
  3) sh/other  ~/.profile

All shells will be configured by default.
Press Enter to configure all, or enter numbers to select (e.g., '1 3'):
```

**Options:**
- Press **Enter** → Configure all detected shells (recommended)
- Type **numbers** → Select specific shells (e.g., `1` for bash only, or `1 2` for bash + zsh)
- Type **none** → Skip shell configuration entirely

**Idempotent:** Running the installer again safely adds configuration to new shells without duplicating existing ones.

After installation, restart your shell or run:
```bash
source ~/.bashrc  # or ~/.zshrc, ~/.profile depending on your shell
```

### Automated Installation

For scripts, CI/CD, or non-interactive environments:

```bash
# Configure all detected shells (default)
echo "" | ./install.sh

# Or use yes for full automation
yes | ./install.sh

# Skip shell configuration
echo "none" | ./install.sh
```

The installer works seamlessly with automation tools like Ansible, Docker, or provisioning scripts.

## Manual Installation

If you prefer to install manually:

### 1. Install files

```bash
# Create directories
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/vup

# Copy files
cp vup-core ~/.local/bin/vup-core
chmod +x ~/.local/bin/vup-core
cp vup.sh ~/.local/share/vup/vup.sh
```

### 2. Configure shell

Add these lines to your shell config (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
# Add ~/.local/bin to PATH (if not already in PATH)
export PATH="$HOME/.local/bin:$PATH"

# vup - Python virtual environment manager
export BASE_PS1='$ '
export VIRTUAL_ENV_DISABLE_PROMPT=1
. ~/.local/share/vup/vup.sh
```

**Important:** Set `BASE_PS1` to your desired prompt format. The example above uses a simple `$ ` prompt. For a more typical prompt:

```bash
export BASE_PS1='\u@\h:\w\$ '  # bash: user@host:path$
# or
export BASE_PS1='%n@%m:%~%# '  # zsh: user@host:path%
```

### 3. Reload shell config

### 4. Reload shell config

```bash
source ~/.bashrc  # or your shell config file
```

## Uninstallation

To remove vup:

```bash
./uninstall.sh
```

This will:
- Remove `vup-core` from `~/.local/bin/`
- Remove `vup.sh` from `~/.local/share/vup/`
- Optionally remove shell integration from config files
- Keep your `.venv/` directories (remove them manually if needed)

## Package Manager Installation

vup is designed to be package-manager friendly. Files should be installed to:

### System-wide installation

```
/usr/local/bin/vup-core          # The Python script
/usr/local/share/vup/vup.sh      # Shell integration
```

Or for distribution packages:
```
/usr/bin/vup-core
/usr/share/vup/vup.sh
```

### Post-install instructions for users

Package managers should display a message instructing users to add to their shell config:

```bash
# vup - Python virtual environment manager
export BASE_PS1='$ '  # Customize this to your preference
export VIRTUAL_ENV_DISABLE_PROMPT=1
. /usr/local/share/vup/vup.sh  # or /usr/share/vup/vup.sh
```

### Example package structures

**Debian/Ubuntu (.deb)**
```
/usr/bin/vup-core
/usr/share/vup/vup.sh
/usr/share/doc/vup/README.md
/usr/share/doc/vup/INSTALL.md
```

**Arch Linux (PKGBUILD)**
```
/usr/bin/vup-core
/usr/share/vup/vup.sh
/usr/share/doc/vup/
```

**Homebrew (macOS/Linux)**
```
$(brew --prefix)/bin/vup-core
$(brew --prefix)/share/vup/vup.sh
```

## Shell Compatibility

vup is POSIX-compliant and tested on:
- **bash** 4.0+
- **zsh** 5.0+
- **dash** 0.5+

Other POSIX shells should work but are not explicitly tested.

## Troubleshooting

### vup command not found

- Ensure `~/.local/bin` is in your PATH
- Check that `vup-core` is executable: `chmod +x ~/.local/bin/vup-core`
- Verify installation: `ls -la ~/.local/bin/vup-core`

### Shell integration not working

- Verify you've sourced the config: `source ~/.bashrc`
- Check that vup.sh exists: `ls -la ~/.local/share/vup/vup.sh`
- Try sourcing directly: `. ~/.local/share/vup/vup.sh`
- Check for syntax errors: `bash -n ~/.local/share/vup/vup.sh`

### "command not found: vup-core" when using vup

- PATH is not set correctly in subshells
- Try restarting your shell completely
- For zsh users: ensure you're not overriding PATH in `.zshenv` or `.zprofile`

### Virtual environment creation fails

- Ensure Python 3.3+ is installed: `python3 --version`
- Check that `python3 -m venv` works: `python3 -m venv /tmp/test-venv`
- Install `python3-venv` package if needed (Debian/Ubuntu)

## Development Installation

For development, you can run vup directly from the repo:

```bash
git clone https://github.com/aricwax/vup.git
cd vup

# Add to your shell config:
export PATH="/path/to/vup:$PATH"
export BASE_PS1='$ '
export VIRTUAL_ENV_DISABLE_PROMPT=1
. /path/to/vup/vup.sh
```

## Testing

After installation, verify vup works:

```bash
# Create test directory
mkdir -p ~/vup-test
cd ~/vup-test

# Test commands
vup help
vup init
vup new test-env
vup ls
vup off

# Clean up
cd ~
rm -rf ~/vup-test
```

## Getting Help

- Run `vup help` for usage information
- Check the [README](README.md) for feature documentation
- See [dev.md](dev.md) for architecture details
- Report issues: https://github.com/aricwax/vup/issues

# vup - Python Virtual Environment Manager

**vup** is a lightweight, intuitive Python virtual environment manager that makes working with venvs effortless. It provides smart venv discovery based on your current directory and works seamlessly across bash, zsh, and dash.

## Why vup?

Traditional Python venv workflows are clunky:
```bash
# The old way
source ~/projects/myapp/.venv/bin/activate  # Long paths
cd ~/projects/myapp/src/components          # Navigate around
source ../../.venv/bin/activate             # Reactivate after cd
```

With vup, it's simple:
```bash
# The vup way
cd ~/projects/myapp/src/components
vup main                                     # Just works
```

**Key features:**
- 🔍 **Smart discovery** - Finds venvs by searching up the directory tree
- 🎯 **Context-aware** - Activate from anywhere in your project
- 🚀 **Fast & lightweight** - Bash + Python, no heavy dependencies
- 🐚 **Multi-shell** - Works with bash, zsh, dash, and POSIX shells
- 🏠 **Home venvs** - Global venvs accessible from anywhere
- 🎨 **Clean prompts** - Shows `(project/venv)` instead of full paths

## Quick Start

### Installation

```bash
git clone https://github.com/your-username/vup.git
cd vup
./install.sh
```

The installer will detect your shells and configure them automatically. Just restart your shell or run:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Basic Usage

```bash
# Create a .venv/ directory
cd ~/myproject
vup init

# Create and activate a venv
vup new main
# Created and activated: ~/myproject/.venv/main

# List available venvs
vup ls
#   main  ~/myproject
#   data  ~

# Activate from anywhere in the project
cd ~/myproject/src/deep/nested/dir
vup main
# Activated main from ~/myproject/.venv/

# Deactivate
vup off
```

## How It Works

### Directory Structure

vup uses a simple convention: all venvs live in `.venv/` directories:

```
~/.venv/              # Home venvs (always accessible)
    main/
    data/

~/projects/foo/.venv/ # Project-specific venvs
    main/
    dev/
```

### Smart Discovery

When you run `vup main`, it searches for `.venv/main/`:
1. Current directory
2. Parent directory
3. Grandparent...
4. Up to `~` (home)

The first valid venv wins (closest to your current directory).

**When outside `~`:** Falls back to `~/.venv/`, making home venvs accessible from anywhere.

## Usage Examples

### Project Workflow

```bash
# Set up a new project
mkdir ~/myproject && cd ~/myproject
vup init
vup new dev

# Work on your project
python app.py
pip install requests

# Create a separate venv for data analysis
vup new data
pip install pandas numpy

# Switch between venvs
vup dev   # Back to dev
vup data  # Back to data

# See what's available
vup ls
# * data  ~/myproject
#   dev   ~/myproject
```

### Home Venvs (Global Access)

```bash
# Create a home venv for general use
cd ~
vup init
vup new main
pip install ipython black ruff

# Access from anywhere
cd /tmp
vup main
# Activated main from ~/.venv/

# Works even outside your home directory!
```

### Multiple Projects

```bash
~/proj/
  web-scraper/
    .venv/
      main/       # Web scraping tools

  api-server/
    .venv/
      main/       # API dependencies
      test/       # Testing tools

# Each project has isolated environments
cd ~/proj/web-scraper
vup main  # Activates web-scraper/main

cd ~/proj/api-server
vup main  # Activates api-server/main (different venv!)
```

## Commands

| Command | Description |
|---------|-------------|
| `vup <name>` | Activate venv (searches upward from cwd) |
| `vup -d <dir> <name>` | Activate venv from specific directory |
| `vup ls [dir]` | List discoverable venvs |
| `vup init` | Create `.venv/` directory |
| `vup new <name>` | Create and activate a new venv |
| `vup rm <name>` | Remove a venv (must be in branch directory) |
| `vup off` | Deactivate current venv |
| `vup help` | Show help message |

## Prompt Customization

vup updates your prompt to show the active venv:

```bash
# Format: (<branch_dir>/<venv_name>) BASE_PS1
(myproject/main) user@host:~/myproject/src$

# For home venvs:
(~/main) user@host:/tmp$
```

Customize by setting `BASE_PS1` in your shell config before sourcing vup:
```bash
export BASE_PS1='\u@\h:\w\$ '  # bash
export BASE_PS1='%n@%m:%~%# '  # zsh
```

## Installation Details

### Quick Install

```bash
./install.sh
```

The installer:
- Detects all your shell configs (`.bashrc`, `.zshrc`, `.profile`)
- Lets you select which shells to configure (default: all)
- Adds `~/.local/bin` to PATH if needed
- Is idempotent (safe to run multiple times)

### Manual Install

See [INSTALL.md](INSTALL.md) for detailed instructions including:
- Manual installation steps
- Package manager guidelines
- Automated/CI installation
- Troubleshooting

## Multi-Shell Support

vup is **POSIX-compliant** and tested on:
- ✅ bash 4.0+
- ✅ zsh 5.0+
- ✅ dash 0.5+

The installer detects and configures all your shells automatically.

## Development

### Architecture

vup uses a hybrid bash/Python architecture:
- **`vup.sh`** - POSIX shell functions (sourced into your shell)
- **`vup-core`** - Python script for complex logic (path traversal, validation)

See [dev.md](dev.md) for complete architecture documentation.

### Testing

```bash
# Run all tests
./test_vup_core.py && ./test_all_shells.sh

# Test specific shell
./test_integration.sh zsh

# Test installation
./test_install_docker.sh
```

vup has comprehensive test coverage:
- 19 Python unit tests
- 12 integration tests per shell
- Multi-shell testing (bash, zsh, dash)
- Docker-based installation testing

## Design Philosophy

vup follows these principles:

1. **Intuitive** - Activate venvs from anywhere in your project
2. **Unobtrusive** - Hidden `.venv/` directories, clean prompts
3. **Standard** - Uses Python's built-in `venv` module
4. **Portable** - POSIX-compliant, works across shells and systems
5. **Simple** - No configuration files, sensible defaults

## Comparison with Other Tools

| Feature | vup | virtualenvwrapper | pyenv-virtualenv |
|---------|-----|-------------------|------------------|
| Discovery by location | ✅ | ❌ | ❌ |
| Project-local venvs | ✅ | ❌ | ✅ |
| Home (global) venvs | ✅ | ✅ | ✅ |
| POSIX-compliant | ✅ | ❌ (bash only) | ❌ (bash only) |
| No config needed | ✅ | ❌ | ❌ |
| Dependencies | Python 3.3+ | virtualenv | pyenv |

## Troubleshooting

**vup command not found:**
- Ensure `~/.local/bin` is in your PATH
- Restart your shell or `source ~/.bashrc`

**vup-core command not found:**
- Check PATH is set correctly in your shell config
- Verify: `ls -la ~/.local/bin/vup-core`

**Shell config not working:**
- Make sure you sourced the config: `source ~/.bashrc`
- Check for errors: `bash -n ~/.local/share/vup/vup.sh`

See [INSTALL.md](INSTALL.md) for more troubleshooting tips.

## Contributing

Contributions are welcome! Please feel free to:
- Report bugs via GitHub issues
- Submit pull requests
- Suggest new features
- Improve documentation

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with ❤️ for developers who love clean, intuitive tools.

Inspired by the early UNIX developers and their philosophy of creating simple tools that do one thing well and compose beautifully with other tools.

---

**Documentation:**
- [INSTALL.md](INSTALL.md) - Complete installation guide
- [dev.md](dev.md) - Architecture and design documentation

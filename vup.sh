# vup.sh - Shell functions for vup virtual environment manager
# POSIX-compliant version - works with bash, zsh, dash, sh, etc.
#
# This file contains shell functions that are sourced into the user's shell
# session. These functions handle all operations that require direct shell
# environment manipulation—things that cannot be done from a subprocess:
#   - Sourcing venv activate scripts
#   - Setting/restoring the PS1 prompt
#   - Deactivation via the deactivate function
#   - Interactive confirmation prompts
#
# The heavy lifting (path traversal, validation, listing) is delegated to
# vup-core, a Python script that communicates via stdout/stderr/exit codes.
#
# Installation:
#   1. Copy vup-core to ~/.local/bin/ (or somewhere in PATH)
#   2. Add to ~/.bashrc (or ~/.zshrc, ~/.profile):
#        PS1_BASE="$PS1"
#        export VIRTUAL_ENV_DISABLE_PROMPT=1
#        . /path/to/vup.sh
#
# Environment variables:
#   PS1_BASE      - The user's original prompt (set before sourcing this file)
#   VIRTUAL_ENV   - Set by activate script, used to detect active venv
#   VIRTUAL_ENV_DISABLE_PROMPT - Must be 1 to prevent default prompt modification
#
# See dev.md for full design documentation.


# vup()
# Main entry point for the vup command.
#
# Routes subcommands to either vup-core (for complex logic) or internal
# handlers (for shell-level operations). Determines if cwd is within ~
# to apply fallback behavior for certain commands.
#
# Subcommands:
#   ls [dir]         - List venvs (delegated to vup-core)
#   init             - Create .venv/ directory (delegated to vup-core)
#   new <name>       - Create venv via vup-core, then activate it
#   rm <name>        - Validate via vup-core, prompt for confirmation, delete
#   off              - Deactivate current venv
#   help, -h, --help - Display help message
#   -d <dir> <name>  - Activate venv from specific directory (no traversal)
#   <name>           - Activate venv (searches upward from cwd to ~)
#
# Returns:
#   0 on success, 1 on error
vup() {
    # Parse -q/--quiet flag
    local quiet=false
    local quiet_flag=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -q|--quiet)
                quiet=true
                quiet_flag="-q"
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    # Check if cwd is within home directory (used for fallback behavior)
    local in_home=true
    case "$PWD" in
        "$HOME"*) ;;
        *) in_home=false ;;
    esac

    case "$1" in
        ls)
            # Delegate listing entirely to vup-core
            shift
            vup-core $quiet_flag ls "$@"
            ;;
        init)
            # Delegate directory creation to vup-core
            vup-core $quiet_flag init
            ;;
        new)
            # Create a new venv and activate it
            if [ -z "$2" ]; then
                [ "$quiet" = false ] && echo "Error: venv name required" >&2
                [ "$quiet" = false ] && echo "Usage: vup new <name>" >&2
                return 1
            fi
            local venv_path
            # vup-core creates the venv and outputs its path on success
            venv_path=$(vup-core $quiet_flag new "$2") || return 1
            _vup_activate "$venv_path" "$quiet"
            ;;
        rm)
            # Remove a venv from the current directory's .venv/
            # This command has NO fallback - user must be in the branch directory
            if [ -z "$2" ]; then
                [ "$quiet" = false ] && echo "Error: venv name required" >&2
                [ "$quiet" = false ] && echo "Usage: vup rm <name>" >&2
                return 1
            fi
            # Require user to be within home directory
            if [ "$in_home" = false ]; then
                [ "$quiet" = false ] && echo "Error: venvs must be removed from their branch directory." >&2
                return 1
            fi
            # Use vup-core to validate the venv exists and is valid
            vup-core $quiet_flag validate ".venv/$2" || return 1
            # Show extra warning when removing from ~/.venv/ (home venvs are global)
            if [ "$PWD" = "$HOME" ]; then
                [ "$quiet" = false ] && echo "Warning: This will permanently remove the '$2' venv from your home directory (~/.venv/)."
            fi
            # Require user to type the venv name to confirm (prevents accidents)
            printf "Type '%s' to confirm removal: " "$2"
            read -r confirm
            if [ "$confirm" = "$2" ]; then
                # Deactivate first if this venv is currently active
                if [ "$VIRTUAL_ENV" = "$PWD/.venv/$2" ]; then
                    _vup_deactivate
                fi
                rm -rf ".venv/$2"
                [ "$quiet" = false ] && echo "Removed $2"
            else
                [ "$quiet" = false ] && echo "Removal cancelled"
            fi
            ;;
        off)
            # Deactivate the current venv
            if [ -n "$VIRTUAL_ENV" ]; then
                _vup_deactivate
            else
                [ "$quiet" = false ] && echo "No venv active"
            fi
            ;;
        help|-h|--help)
            # Try vup-core help first, fall back to built-in help
            vup-core help 2>/dev/null || _vup_help
            ;;
        -d)
            # Activate venv from a specific directory (no upward traversal)
            if [ -z "$2" ] || [ -z "$3" ]; then
                [ "$quiet" = false ] && echo "Error: directory and venv name required" >&2
                [ "$quiet" = false ] && echo "Usage: vup -d <dir> <name>" >&2
                return 1
            fi
            local venv_path
            # --no-traverse ensures we only look in the specified directory
            venv_path=$(vup-core $quiet_flag find "$3" --start-dir "$2" --no-traverse) || return 1
            _vup_activate "$venv_path" "$quiet"
            ;;
        "")
            # No arguments - show help
            _vup_help
            ;;
        *)
            # Default: treat argument as venv name, search upward from cwd
            local venv_path
            venv_path=$(vup-core $quiet_flag find "$1") || return 1
            _vup_activate "$venv_path" "$quiet"
            ;;
    esac
}

# _vup_activate <venv_path> [quiet]
# Activate a virtual environment at the given path.
#
# This function handles the shell-level activation that cannot be done from
# a subprocess. It deactivates any currently active venv, sources the new
# venv's activate script, and sets up the custom prompt.
#
# Args:
#   venv_path - Full path to the venv directory (e.g., ~/proj/.venv/main)
#   quiet     - Optional: "true" to suppress output, "false" otherwise
#
# Side effects:
#   - Sources <venv_path>/bin/activate (sets VIRTUAL_ENV, modifies PATH)
#   - Sets PS1 to custom format: (<branch>/<name>) $PS1_BASE
#   - Prints activation message to stdout (unless quiet)
_vup_activate() {
    local venv_path="$1"
    local quiet="${2:-false}"
    # Deactivate any existing venv first (clean switch)
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate 2>/dev/null
    fi
    # Source the venv's activate script (this sets VIRTUAL_ENV and modifies PATH)
    . "$venv_path/bin/activate"
    # Generate and set custom prompt using vup-core
    local prompt_id
    prompt_id=$(vup-core prompt "$venv_path")
    PS1="($prompt_id) $PS1_BASE"
    # Confirm activation to user (unless quiet mode)
    [ "$quiet" = false ] && echo "Activated $(basename "$venv_path") from $(dirname "$venv_path")/"
}

# _vup_deactivate()
# Deactivate the current virtual environment and restore the prompt.
#
# Calls the deactivate function (defined by the venv's activate script)
# and restores PS1 to the user's original prompt.
#
# Side effects:
#   - Calls deactivate (unsets VIRTUAL_ENV, restores PATH)
#   - Restores PS1 to $PS1_BASE
_vup_deactivate() {
    deactivate 2>/dev/null
    PS1="$PS1_BASE"
}

# _vup_help()
# Display usage information.
#
# This is a fallback help function used when vup-core is not available.
# The output matches vup-core's help command for consistency.
_vup_help() {
    cat << 'EOF'
vup - Python virtual environment manager

Usage:
  vup <name>           Activate venv (searches upward from cwd to ~)
  vup -d <dir> <name>  Activate venv from specific directory (no traversal)
  vup ls [dir]         List discoverable venvs
  vup init             Create .venv/ directory in cwd
  vup new <name>       Create and activate a new venv
  vup rm <name>        Remove a venv (must be in branch directory)
  vup off              Deactivate current venv
  vup help             Show this help message

Options:
  -q, --quiet          Suppress informational output

Environment:
  venvs are stored in .venv/ directories
  Search starts from cwd and traverses up to ~
  When outside ~, commands fall back to ~/.venv/
EOF
}

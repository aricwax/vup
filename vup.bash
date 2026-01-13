# vup.bash - Shell functions for vup virtual environment manager
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
#   2. Add to ~/.bashrc:
#        BASE_PS1="$PS1"
#        export VIRTUAL_ENV_DISABLE_PROMPT=1
#        source /path/to/vup.bash
#
# Environment variables:
#   BASE_PS1      - The user's original prompt (set before sourcing this file)
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
    # Check if cwd is within home directory (used for fallback behavior)
    local in_home=true
    case "$PWD" in
        "$HOME"*) ;;
        *) in_home=false ;;
    esac

    case "$1" in
        ls)
            # Delegate listing entirely to vup-core
            vup-core ls "${@:2}"
            ;;
        init)
            # Delegate directory creation to vup-core
            vup-core init
            ;;
        new)
            # Create a new venv and activate it
            if [[ -z "$2" ]]; then
                echo "Error: venv name required" >&2
                echo "Usage: vup new <name>" >&2
                return 1
            fi
            local path
            # vup-core creates the venv and outputs its path on success
            path=$(vup-core new "$2") || return 1
            _vup_activate "$path"
            ;;
        rm)
            # Remove a venv from the current directory's .venv/
            # This command has NO fallback - user must be in the branch directory
            if [[ -z "$2" ]]; then
                echo "Error: venv name required" >&2
                echo "Usage: vup rm <name>" >&2
                return 1
            fi
            # Require user to be within home directory
            if [[ "$in_home" == false ]]; then
                echo "Error: venvs must be removed from their branch directory." >&2
                return 1
            fi
            # Use vup-core to validate the venv exists and is valid
            vup-core validate ".venv/$2" || return 1
            # Show extra warning when removing from ~/.venv/ (home venvs are global)
            if [[ "$PWD" == "$HOME" ]]; then
                echo "Warning: This will permanently remove the '$2' venv from your home directory (~/.venv/)."
            fi
            # Require user to type the venv name to confirm (prevents accidents)
            read -p "Type '$2' to confirm removal: " confirm
            if [[ "$confirm" == "$2" ]]; then
                # Deactivate first if this venv is currently active
                if [[ "$VIRTUAL_ENV" == "$PWD/.venv/$2" ]]; then
                    _vup_deactivate
                fi
                rm -rf ".venv/$2"
                echo "Removed $2"
            else
                echo "Removal cancelled"
            fi
            ;;
        off)
            # Deactivate the current venv
            if [[ -n "$VIRTUAL_ENV" ]]; then
                _vup_deactivate
            else
                echo "No venv active"
            fi
            ;;
        help|-h|--help)
            # Try vup-core help first, fall back to built-in help
            vup-core help 2>/dev/null || _vup_help
            ;;
        -d)
            # Activate venv from a specific directory (no upward traversal)
            if [[ -z "$2" || -z "$3" ]]; then
                echo "Error: directory and venv name required" >&2
                echo "Usage: vup -d <dir> <name>" >&2
                return 1
            fi
            local path
            # --no-traverse ensures we only look in the specified directory
            path=$(vup-core find "$3" --start-dir "$2" --no-traverse) || return 1
            _vup_activate "$path"
            ;;
        "")
            # No arguments - show help
            _vup_help
            ;;
        *)
            # Default: treat argument as venv name, search upward from cwd
            local path
            path=$(vup-core find "$1") || return 1
            _vup_activate "$path"
            ;;
    esac
}

# _vup_activate <venv_path>
# Activate a virtual environment at the given path.
#
# This function handles the shell-level activation that cannot be done from
# a subprocess. It deactivates any currently active venv, sources the new
# venv's activate script, and sets up the custom prompt.
#
# Args:
#   venv_path - Full path to the venv directory (e.g., ~/proj/.venv/main)
#
# Side effects:
#   - Sources <venv_path>/bin/activate (sets VIRTUAL_ENV, modifies PATH)
#   - Sets PS1 to custom format: (<branch>/<name>) $BASE_PS1
#   - Prints activation message to stdout
_vup_activate() {
    local venv_path="$1"
    # Deactivate any existing venv first (clean switch)
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate 2>/dev/null
    fi
    # Source the venv's activate script (this sets VIRTUAL_ENV and modifies PATH)
    source "$venv_path/bin/activate"
    # Generate and set custom prompt using vup-core
    local prompt_id
    prompt_id=$(vup-core prompt "$venv_path")
    PS1="($prompt_id) $BASE_PS1"
    # Confirm activation to user
    echo "Activated $(basename "$venv_path") from $(dirname "$venv_path")/"
}

# _vup_deactivate()
# Deactivate the current virtual environment and restore the prompt.
#
# Calls the deactivate function (defined by the venv's activate script)
# and restores PS1 to the user's original prompt.
#
# Side effects:
#   - Calls deactivate (unsets VIRTUAL_ENV, restores PATH)
#   - Restores PS1 to $BASE_PS1
_vup_deactivate() {
    deactivate 2>/dev/null
    PS1="$BASE_PS1"
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

Environment:
  venvs are stored in .venv/ directories
  Search starts from cwd and traverses up to ~
  When outside ~, commands fall back to ~/.venv/
EOF
}

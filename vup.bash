# vup.bash - Shell functions for vup virtual environment manager
# See dev.md for design documentation
#
# Installation:
#   1. Copy vup-core to ~/.local/bin/ (or somewhere in PATH)
#   2. Add to ~/.bashrc:
#        BASE_PS1="$PS1"
#        export VIRTUAL_ENV_DISABLE_PROMPT=1
#        source /path/to/vup.bash

vup() {
    local in_home=true
    case "$PWD" in
        "$HOME"*) ;;
        *) in_home=false ;;
    esac

    case "$1" in
        ls)
            vup-core ls "${@:2}"
            ;;
        init)
            vup-core init
            ;;
        new)
            if [[ -z "$2" ]]; then
                echo "Error: venv name required" >&2
                echo "Usage: vup new <name>" >&2
                return 1
            fi
            local path
            path=$(vup-core new "$2") || return 1
            _vup_activate "$path"
            ;;
        rm)
            if [[ -z "$2" ]]; then
                echo "Error: venv name required" >&2
                echo "Usage: vup rm <name>" >&2
                return 1
            fi
            # rm has no fallback - must be in branch directory
            if [[ "$in_home" == false ]]; then
                echo "Error: venvs must be removed from their branch directory." >&2
                return 1
            fi
            # Validate venv exists in current directory
            vup-core validate ".venv/$2" || return 1
            # Extra warning for home venvs
            if [[ "$PWD" == "$HOME" ]]; then
                echo "Warning: This will permanently remove the '$2' venv from your home directory (~/.venv/)."
            fi
            read -p "Type '$2' to confirm removal: " confirm
            if [[ "$confirm" == "$2" ]]; then
                # Deactivate if this venv is active
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
            if [[ -n "$VIRTUAL_ENV" ]]; then
                _vup_deactivate
            else
                echo "No venv active"
            fi
            ;;
        help|-h|--help)
            vup-core help 2>/dev/null || _vup_help
            ;;
        -d)
            if [[ -z "$2" || -z "$3" ]]; then
                echo "Error: directory and venv name required" >&2
                echo "Usage: vup -d <dir> <name>" >&2
                return 1
            fi
            local path
            path=$(vup-core find "$3" --start-dir "$2" --no-traverse) || return 1
            _vup_activate "$path"
            ;;
        "")
            _vup_help
            ;;
        *)
            local path
            path=$(vup-core find "$1") || return 1
            _vup_activate "$path"
            ;;
    esac
}

_vup_activate() {
    local venv_path="$1"
    # Deactivate any existing venv
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate 2>/dev/null
    fi
    # Source the activate script
    source "$venv_path/bin/activate"
    # Update prompt with custom format
    local prompt_id
    prompt_id=$(vup-core prompt "$venv_path")
    PS1="($prompt_id) $BASE_PS1"
    # Print activation message
    echo "Activated $(basename "$venv_path") from $(dirname "$venv_path")/"
}

_vup_deactivate() {
    deactivate 2>/dev/null
    PS1="$BASE_PS1"
}

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

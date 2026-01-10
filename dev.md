# vup - Python Virtual Environment Manager

## Design

### Overview

`vup` is a Python virtual environment management tool that provides intuitive venv discovery and activation based on directory context. It searches for `.venv/` directories starting from the current working directory and traversing up the filesystem tree to `~`, allowing users to activate venvs from anywhere within a project hierarchy.

**Scope:** `vup` manages venvs within the user's home directory (`~`). When operating outside of `~`, most commands fall back to `~/.venv/` so that home venvs remain accessible from anywhere in the filesystem.

### Architecture

The tool uses a hybrid bash/Python architecture:

- **Bash function (`vup`)** - The user-facing entry point, sourced into the shell via a user's `~/.bashrc` or `~/.bash_funcs` file. Handles shell-level operations that cannot be done from a subprocess:
  - Sourcing the venv `activate` script
  - Setting/restoring the `PS1` prompt
  - Deactivation
  - Routing subcommands to the Python core
  - Interactive confirmation prompts

- **Python script (`vup-core`)** - Handles all complex logic:
  - Directory traversal and `.venv/` discovery
  - venv validation (checking for `bin/activate`)
  - Listing all discoverable venvs
  - Creating new venvs
  - Prompt identifier generation

### Directory Structure Convention

All virtual environments are stored in hidden `.venv/` directories:

```
~/.venv/              # Home venvs (always accessible)
    main/
    data/

~/proj/foo/.venv/     # Project-specific venvs
    main/
    dev/

~/proj/other-project/.venv/
    main/
```

This convention:
- Keeps venvs hidden and tidy
- Allows a standard `.gitignore` entry (`.venv/`)
- Enables intuitive discovery based on directory context

### Search Behavior

When activating a venv (e.g., `vup main`), the tool searches for `.venv/main/` in:
1. Current directory
2. Parent directory
3. Continue up the tree...
4. `~` (home directory)

The first valid match wins (closest to current directory takes precedence).

**When outside `~`:** Falls back to `~/.venv/` directly, making home venvs accessible from anywhere.

### Prompt Customization

When a venv is activated, the prompt is updated to show the venv identifier in the format `(<branch_dir>/<venv_name>)`. Examples:
- For `~/.venv/main` → `(~/main)`
- For `~/proj/foo/.venv/main` → `(foo/main)`

The `<branch_dir>` is the directory containing the `.venv/` folder:
- If the branch directory is `~`, display as `~`
- Otherwise, display the directory name (not full path)

The prompt format is: `(<branch_dir>/<venv_name>) BASE_PS1$ `

---

## Requirements

### R0: Scope and Fallback Behavior

**R0.1** - `vup` primarily operates within the user's home directory (`~`). When the current working directory is outside of `~`, commands fall back to operating on `~/.venv/` instead.

**R0.2** - Fallback behavior by command when outside `~`:
| Command | Behavior outside `~` |
|---------|---------------------|
| `vup <name>` | Activates `~/.venv/<name>` |
| `vup ls` | Lists venvs in `~/.venv/` only |
| `vup init` | Creates `~/.venv/` if it doesn't exist |
| `vup new <name>` | Creates `~/.venv/<name>` (auto-creates `~/.venv/` if needed) |
| `vup rm <name>` | **Error** - must be in branch directory |
| `vup off` | Works normally |
| `vup help` | Works normally |
| `vup -d <dir> <name>` | `<dir>` must be within `~`, otherwise error |

### R1: Activation (`vup <name>`)

**R1.1** - When `vup <name>` is called from within `~`, search for a valid venv at `.venv/<name>/` starting from the current directory, and if not found, progressively traverse up to `~`, searching at each directory level.

**R1.2** - When `vup <name>` is called from outside `~`, fall back directly to `~/.venv/<name>`.

**R1.3** - At each directory level, perform validation in this order:
1. Check if `.venv` exists
   - If `.venv` does not exist, continue to next directory level (no warning)
   - If `.venv` exists but is not a directory, print warning and continue to next directory level
2. Check if `.venv/<name>` exists
   - If `.venv/<name>` does not exist, continue to next directory level (no warning)
   - If `.venv/<name>` exists but is not a directory, print warning and continue to next directory level
3. Check if `.venv/<name>/bin/activate` exists
   - If it does not exist, print warning and continue to next directory level
   - If it exists, this is a valid venv - proceed with activation

**R1.4** - If no valid venv is found after exhausting the search path, print an error message.

**R1.5** - On successful activation, print a message showing which venv was activated and its location (e.g., "Activated main from ~/proj/foo/.venv/").

**R1.6** - On successful activation, update `PS1` to show the venv identifier as specified in the "Prompt Customization" section above.

**R1.7** - Disable the default venv prompt modification (`VIRTUAL_ENV_DISABLE_PROMPT=1`) to use custom prompt handling.

**R1.8** - If a venv is already active when activating a new one, implicitly deactivate the current venv first (restore `PS1`), then activate the new venv.

### R2: Directory Override (`vup -d <dir> <name>`)

**R2.1** - The `-d` flag specifies a directory for the search instead of the current directory.

**R2.2** - The `<dir>` path follows standard Linux path conventions:
- Relative paths are relative to the current working directory
- Absolute paths and paths starting with `~` are interpreted as-is
- The resolved path must be within `~`, otherwise print an error
- Example: `vup -d ~/proj/foo main` activates `~/proj/foo/.venv/main`
- Example: `vup -d ../bar main` activates `./../bar/.venv/main` (relative to cwd)

**R2.3** - The search DOES NOT traverse up from the specified directory. If the venv `<name>` does not exist or is not valid in `<dir>/.venv/`, print an error message (same validation and error behavior as R1.3/R1.4, but without upward traversal).

### R3: Listing (`vup ls [dir]`)

**R3.1** - List all discoverable venvs from the starting directory up to `~`.
- If `[dir]` is provided, start from that directory (following same path conventions as R2.2); `[dir]` must be within `~`
- If `[dir]` is omitted and cwd is within `~`, start from the current directory
- If `[dir]` is omitted and cwd is outside `~`, list venvs in `~/.venv/` only

**R3.2** - For each venv, display:
- A `*` character in the first column to indicate the currently active venv (space otherwise)
- The venv name in the second column
- The path to the branch directory (the directory containing the `.venv/`) in the third column
- Columns are aligned with two spaces between them

**R3.3** - Example output of `vup ls` from current directory `~/proj/foo/webscrape`:
```
  web       ~/proj/foo/webscrape
* main      ~/proj/foo
  data      ~
  main      ~
  longname  ~
```

### R4: Initializing (`vup init`)

**R4.1** - Determine target directory:
- If cwd is within `~`, target is current directory
- If cwd is outside `~`, target is `~`

**R4.2** - If `.venv` exists in the target directory, print an error message that includes:
- Indication that `.venv` already exists
- Suggestion to use `vup new <name>` to create a new venv

**R4.3** - If `.venv` does not exist in the target directory, create it and exit silently.

### R5: Creating (`vup new <name>`)

**R5.1** - Determine target directory:
- If cwd is within `~`, target is current directory
- If cwd is outside `~`, target is `~`

**R5.2** - If cwd is within `~` and `.venv/` does not exist in the current directory, print an error and suggest using the `vup init` command.

**R5.3** - If cwd is outside `~` and `~/.venv/` does not exist, automatically create it (convenience feature for creating home venvs from anywhere).

**R5.4** - If `.venv/<name>` already exists in the target directory, print an error indicating the venv already exists.

**R5.5** - Use `python3 -m venv <target>/.venv/<name>` to create the venv.

**R5.6** - Print success message with the full path of the created venv.

**R5.7** - After successful creation, automatically activate the new venv (following the activation behavior in R1.5 and R1.6).

### R6: Removing (`vup rm <name>`)

**R6.1** - `vup rm` has NO fallback behavior. The user must be in the branch directory (the directory containing `.venv/`) to remove a venv. If cwd is outside `~`, print error: "venvs must be removed from their branch directory."

**R6.2** - Check for venv in current directory only (no upward tree traversal):
- If `.venv/` does not exist in current directory, print error: venvs must be removed from their branch directory
- If `.venv/<name>` does not exist, print error: venv not found in current directory's `.venv/`
- If `.venv/<name>` exists but is not a valid venv (no `bin/activate`), print error about invalid venv

**R6.3** - **Extra warning for home venvs:** If the current directory is `~` (removing from `~/.venv/`), display an additional warning before the confirmation prompt:
```
Warning: This will permanently remove the '<name>' venv from your home directory (~/.venv/).
```

**R6.4** - Prompt user to type the name of the venv to confirm removal:
- An exact case-sensitive match to `<name>` proceeds with removal
- Any other input cancels the removal and prints a cancellation message

**R6.5** - If the venv being removed is currently active, deactivate it after confirmation but before deletion.

**R6.6** - On successful deletion, print a confirmation message.

### R7: Deactivation (`vup off`)

**R7.1** - If a venv is currently active:
- Deactivate it
- Restore `PS1` to the base prompt (without venv prefix)

**R7.2** - If no venv is active, print a message indicating there's nothing to deactivate.

### R8: Validation

**R8.1** - Validation logic is handled by a reusable function `validate_venv(path)` within `vup-core`.

**R8.2** - A path is a valid venv if and only if:
- The path exists and is a directory
- The path contains `bin/activate`

**R8.3** - The validation function returns an exit code: 0=valid, 1=not found, 2=not a directory, 3=no `bin/activate`.

### R9: Help (`vup help` or `vup -h` or `vup --help`)

**R9.1** - Display usage information and available subcommands.

---

## Planning

### Architecture Details

#### Responsibility Split

The hybrid architecture exists because **bash must handle anything that modifies the shell environment** - this cannot be done from a subprocess.

| `vup-core` (Python) | `vup` (Bash function) |
|---------------------|----------------------|
| Path traversal & search | Source activate scripts |
| Validation logic | Set/restore PS1 |
| Listing & formatting | Deactivation |
| Creating venvs | Interactive confirmation (rm) |
| Prompt string generation | Subcommand routing |
| Fallback path resolution | Home venv warning (rm) |

#### `vup-core` Subcommands

Each subcommand communicates with bash via stdout, stderr, and exit codes.

**Argument validation:** `vup-core` handles all argument validation (missing args, invalid paths, etc.) and outputs appropriate error messages to stderr. The bash function simply passes arguments through and returns the exit code. This keeps validation logic centralized and testable.

**`find <name> [--start-dir <dir>] [--no-traverse]`**
- Searches for a venv by name
- stdout: Full path to venv (e.g., `/home/user/proj/foo/.venv/main`)
- stderr: Error/warning messages
- Exit 0 on success, non-zero on failure
- `--no-traverse` disables upward directory traversal (for `-d` flag behavior)
- Handles fallback to `~/.venv/` when outside `~`

**`ls [--start-dir <dir>]`**
- Lists all discoverable venvs
- stdout: Formatted, aligned table ready to print (Python handles alignment)
- stderr: Error messages
- Exit 0 on success, non-zero on failure
- Handles fallback to `~/.venv/` when outside `~`

**`validate <path>`**
- Checks if a path is a valid venv
- stdout: (empty)
- stderr: Human-readable error message if invalid
- Exit codes: 0=valid, 1=not found, 2=not a directory, 3=no `bin/activate`

**`init`**
- Creates `.venv/` in current directory (or `~/.venv/` if outside `~`)
- stdout: (empty on success)
- stderr: Error message if `.venv` already exists
- Exit 0 on success, non-zero on failure

**`new <name>`**
- Creates a new venv
- stdout: Full path to created venv
- stderr: Error messages
- Exit 0 on success, non-zero on failure
- When outside `~`, creates in `~/.venv/` and auto-creates `~/.venv/` if needed

**`prompt <venv-path>`**
- Generates prompt identifier from venv path
- stdout: Prompt string (e.g., `foo/main` or `~/main`)
- Exit 0 always

#### Bash Function Structure

```bash
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
            local path
            path=$(vup-core new "$2") || return 1
            _vup_activate "$path"
            ;;
        rm)
            # rm has no fallback - must be in branch directory
            if [[ "$in_home" == false ]]; then
                echo "Error: venvs must be removed from their branch directory." >&2
                return 1
            fi
            vup-core validate ".venv/$2" || return 1
            # Extra warning for home venvs
            if [[ "$PWD" == "$HOME" ]]; then
                echo "Warning: This will permanently remove the '$2' venv from your home directory (~/.venv/)."
            fi
            read -p "Type '$2' to confirm removal: " confirm
            if [[ "$confirm" == "$2" ]]; then
                [[ "$VIRTUAL_ENV" == "$PWD/.venv/$2" ]] && _vup_deactivate
                rm -rf ".venv/$2"
                echo "Removed $2"
            else
                echo "Removal cancelled"
            fi
            ;;
        off)
            [[ -n "$VIRTUAL_ENV" ]] && _vup_deactivate || echo "No venv active"
            ;;
        help|-h|--help)
            vup-core help
            ;;
        -d)
            local path
            path=$(vup-core find "$3" --start-dir "$2" --no-traverse) || return 1
            _vup_activate "$path"
            ;;
        *)
            local path
            path=$(vup-core find "$1") || return 1
            _vup_activate "$path"
            ;;
    esac
}

_vup_activate() {
    [[ -n "$VIRTUAL_ENV" ]] && deactivate
    source "$1/bin/activate"
    PS1="($(vup-core prompt "$1")) $BASE_PS1\$ "
    echo "Activated $(basename "$1") from $(dirname "$1")/"
}

_vup_deactivate() {
    deactivate
    PS1="$BASE_PS1\$ "
}
```

### Phase 1: Core Infrastructure

#### Task 1.1: Create `vup-core` Python script [DONE]
- Location: `~/.local/bin/vup-core`
- Single executable Python file with argparse for subcommand handling
- Implement subcommands: `find`, `ls`, `validate`, `init`, `new`, `prompt`, `help`

#### Task 1.2: Create `vup` bash function [DONE]
- Location: `vup.bash` in repo (install to `~/.bash_funcs`)
- Implement subcommand routing and shell-level operations
- Helper functions: `_vup_activate`, `_vup_deactivate`

#### Task 1.3: Update `~/.bashrc`
- Define `BASE_PS1` without trailing `$`
- Source `~/.bash_funcs`
- Set `VIRTUAL_ENV_DISABLE_PROMPT=1`

### Phase 2: Implementation Details

#### Task 2.1: Implement search algorithm in Python [DONE]
- Start from current (or specified) directory
- Walk up to `~`
- Fallback to `~/.venv/` if outside `~`
- Validate each candidate using `validate_venv()`
- Return first valid match or error
- Support `--no-traverse` flag for `-d` behavior

#### Task 2.2: Implement prompt generation [DONE]
- Helper function to compute venv display name from path
- Extract branch directory from venv path
- Format as `<branch_dir>/<venv_name>`
- Handle `~` display for home directory

#### Task 2.3: Implement `ls` output formatting [DONE]
- Traverse full search path
- Collect all venvs with metadata (name, branch dir, full path)
- Detect currently active venv via `$VIRTUAL_ENV`
- Format aligned columns with active indicator
- Fallback to `~/.venv/` listing when outside `~`

#### Task 2.4: Implement `init` [DONE]
- Check for existing `.venv/`
- Create directory or error appropriately
- Handle fallback to `~/.venv/` when outside `~`

#### Task 2.5: Implement `new` with validation [DONE]
- Check for existing `.venv/` directory (or auto-create when outside `~`)
- Check for existing `.venv/<name>`
- Create venv with `python3 -m venv`

#### Task 2.6: Implement `rm` support [DONE]
- `validate` subcommand returns status for bash to handle confirmation
- Bash handles interactive prompt, warning for home venvs, and deletion

### Phase 3: Installation & Polish

#### Task 3.1: Create installation script
- Copy `vup-core` to `~/.local/bin/`
- Make executable
- Add `vup` function to `~/.bash_funcs`
- Update `~/.bashrc` if needed

#### Task 3.2: Testing
- Test activation from various directories within `~`
- Test fallback behavior when outside `~`
- Test prompt formatting
- Test switching between venvs
- Test init/new/rm commands
- Test `vup ls` with and without directory argument
- Test home venv removal warning

#### Task 3.3: Documentation
- Usage examples in README
- Installation instructions

---

## Open Questions

1. ~~Should `vup-core` be a single Python file or a small package?~~ **Decided:** Single file to start, can refactor later if needed.
2. ~~Where should `vup-core` be installed?~~ **Decided:** `~/.local/bin/vup-core`
3. ~~Should vup work outside of `~`?~~ **Decided:** Yes, with fallback to `~/.venv/` for most commands. Exception: `vup rm` requires being in the branch directory.
4. Color scheme for prompt venv indicator? (Deferred for now)

# vup - Python Virtual Environment Manager

## Overview

`vup` is a Python virtual environment management tool that provides intuitive venv discovery and activation based on directory context. It searches for `.venv/` directories starting from the current working directory and traversing up the filesystem tree to `~`, allowing users to activate venvs from anywhere within a project hierarchy.

**Scope:** `vup` manages venvs within the user's home directory (`~`). When operating outside of `~`, most commands fall back to `~/.venv/` so that home venvs remain accessible from anywhere in the filesystem.

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

The prompt format is: `(<branch_dir>/<venv_name>) PS1_BASE$ `


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

## Architecture

### Responsibility Split

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

The hybrid architecture exists because **bash must handle anything that modifies the shell environment** - this cannot be done from a subprocess.

| `vup-core` (Python script) | `vup` (Bash function)         |
| -------------------------- | ----------------------------- |
| Path traversal & search    | Source activate scripts       |
| Validation logic           | Set/restore PS1               |
| Listing & formatting       | Deactivation                  |
| Creating venvs             | Interactive confirmation (rm) |
| Prompt string generation   | Subcommand routing            |
| Fallback path resolution   | Home venv warning (rm)        |

### `vup-core`

#### About

`vup-core` is a single-file Python script located at `~/.local/bin/vup-core`. It serves as the backend for all complex logic that doesn't require direct shell environment manipulation.

The script uses `argparse` for subcommand routing and communicates with the bash frontend through:
- **stdout**: Output data (venv paths, formatted listings, prompt strings)
- **stderr**: Error and warning messages
- **Exit codes**: 0 for success, non-zero for various failure conditions

Key helper functions:
- `is_within_home(path)` - Checks if a path is within `~`
- `validate_venv(path)` - Validates a venv directory, returning exit codes per R8.3

#### Subcommands

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

**`help`**
- Displays user-facing help message
- stdout: Usage information and available commands
- Exit 0 always

### `vup.sh`

#### About

`vup.sh` is a POSIX-compliant shell script containing functions that are sourced into the user's shell session (typically via `~/.bashrc`, `~/.zshrc`, or `~/.profile`). These functions handle all operations that require direct shell environment manipulation—things that cannot be done from a subprocess.

The script is fully compatible with bash, zsh, dash, and other POSIX-compliant shells. Installation requires setting `PS1_BASE` to the user's prompt before sourcing, and exporting `VIRTUAL_ENV_DISABLE_PROMPT=1` to prevent the default venv prompt modification.

#### Functions

**`vup`**
The main entry point. Routes subcommands to either `vup-core` or internal handlers:
- `ls`, `init`: Passed directly to `vup-core`
- `new <name>`: Calls `vup-core new`, then activates the created venv
- `rm <name>`: Validates via `vup-core`, handles confirmation prompt, performs deletion
- `off`: Deactivates current venv
- `help`, `-h`, `--help`: Displays help (tries `vup-core help`, falls back to `_vup_help`)
- `-d <dir> <name>`: Calls `vup-core find` with `--no-traverse`, then activates
- `<name>` (default): Calls `vup-core find`, then activates

**`_vup_activate <venv_path>`**
Activates a venv at the given path:
1. Deactivates any currently active venv
2. Sources `<venv_path>/bin/activate`
3. Generates prompt identifier via `vup-core prompt`
4. Sets `PS1` to `(<prompt_id>) $PS1_BASE`
5. Prints activation message

**`_vup_deactivate`**
Deactivates the current venv and restores `PS1` to `$PS1_BASE`.

**`_vup_help`**
Displays usage information as a fallback when `vup-core help` is unavailable.

---

## Testing

The test suite is split into multiple files covering different aspects:

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test_vup_core.py` | 19 | Unit tests for the Python backend via subprocess |
| `test_integration.sh` | 12 | End-to-end tests for shell workflow (parameterized by shell) |
| `test_all_shells.sh` | N/A | Wrapper that runs integration tests across bash, zsh, and dash |
| `test_install_docker.sh` | N/A | Tests installation in clean Ubuntu Docker container |

Run all tests with: `./test_vup_core.py && ./test_all_shells.sh`

The integration tests are POSIX-compliant and work across multiple shells, ensuring vup functions correctly in bash, zsh, and dash environments.

### `test_vup_core.py`

#### About

`test_vup_core.py` tests the `vup-core` Python script by invoking it as a subprocess, simulating how the bash function calls it. Each test creates isolated temporary directories within `$HOME` to test venv operations without affecting the user's actual venvs.

The `run()` helper function invokes `vup-core` with arguments and returns `(returncode, stdout, stderr)`, allowing tests to verify all three communication channels.

#### Test Cases

**Help:**
- `test_help` - Verifies `help` subcommand displays usage information

**Validation (`validate` subcommand):**
- `test_validate_not_found` - Returns exit code 1 for non-existent paths
- `test_validate_not_directory` - Returns exit code 2 when path is a file
- `test_validate_no_activate` - Returns exit code 3 when `bin/activate` is missing
- `test_validate_valid` - Returns exit code 0 for valid venv structure

**Initialization (`init` subcommand):**
- `test_init_creates_venv_dir` - Creates `.venv/` directory in cwd
- `test_init_fails_if_exists` - Fails with error when `.venv/` already exists

**Creation (`new` subcommand):**
- `test_new_creates_venv` - Creates a functional venv with `bin/activate`
- `test_new_fails_without_init` - Fails when `.venv/` doesn't exist (requires `init` first)
- `test_new_fails_if_exists` - Fails when venv name already exists

**Search (`find` subcommand):**
- `test_find_locates_venv` - Finds venv in current directory's `.venv/`
- `test_find_traverses_up` - Finds venv in parent directory (upward traversal)
- `test_find_no_traverse_flag` - `--no-traverse` disables upward search
- `test_find_not_found` - Returns error when venv doesn't exist

**Listing (`ls` subcommand):**
- `test_ls_lists_venvs` - Lists all venvs in `.venv/` directory
- `test_ls_empty` - Returns success even when no venvs exist
- `test_ls_shows_active` - Marks active venv with `*` (via `VIRTUAL_ENV` env var)

**Prompt generation (`prompt` subcommand):**
- `test_prompt_home_venv` - Generates `~/name` format for `~/.venv/` venvs
- `test_prompt_project_venv` - Generates `project/name` format for project venvs

### `test_integration.sh`

#### About

`test_integration.sh` tests the `vup` shell function by running it in real subshells with a proper shell environment. Unlike the Python tests which test `vup-core` in isolation, these tests verify the full user-facing workflow including shell environment manipulation (`PS1`, `VIRTUAL_ENV`, sourcing activate scripts).

The test script accepts an optional shell parameter (defaults to bash), allowing it to test vup across different shells:
```bash
./test_integration.sh bash  # Test with bash
./test_integration.sh zsh   # Test with zsh
./test_integration.sh dash  # Test with dash
```

Each test uses `setup()` and `teardown()` to create and clean up isolated temporary directories under `$HOME`. The `run_vup()` helper spawns a subshell using the specified shell, sources `vup.sh`, and runs commands with proper environment setup (`PS1_BASE`, `VIRTUAL_ENV_DISABLE_PROMPT`).

#### Test Cases

**Help:**
- `test_help` - `vup help` displays usage information
- `test_no_args` - `vup` with no arguments shows help

**Core workflow:**
- `test_init` - `vup init` creates `.venv/` directory
- `test_new` - `vup new` creates venv and activates it
- `test_activate` - `vup <name>` activates an existing venv
- `test_ls` - `vup ls` lists all venvs

**Deactivation:**
- `test_off` - `vup off` deactivates current venv (unsets `VIRTUAL_ENV`)
- `test_off_none` - `vup off` prints message when no venv is active

**Advanced features:**
- `test_subdir_activation` - Activating from subdirectory finds parent's venv (upward traversal)
- `test_prompt` - Prompt identifier uses correct `<branch>/<name>` format
- `test_dash_d` - `vup -d <dir> <name>` activates from specific directory
- `test_switch` - Activating new venv implicitly deactivates the old one

### `test_all_shells.sh`

#### About

`test_all_shells.sh` is a wrapper script that runs `test_integration.sh` with multiple shells to verify POSIX compliance and cross-shell compatibility.

#### Shells Tested

- **bash** - Reference implementation
- **zsh** - Popular alternative shell
- **dash** - Strict POSIX compliance check

If a shell is not installed, it will be skipped with a warning. The script exits with an error if any shell fails its tests.

Run with: `./test_all_shells.sh`

### `test_install_docker.sh`

#### About

`test_install_docker.sh` tests the installation process in a clean Ubuntu 22.04 Docker container. This ensures the installer works correctly in a fresh environment without any existing configuration or dependencies (beyond the prerequisites).

#### What It Tests

1. File installation to correct locations (`~/.local/bin/`, `~/.local/share/vup/`)
2. Shell configuration is added correctly
3. PATH is properly configured
4. `vup` command works after installation

This test simulates what a new user would experience when installing vup for the first time.

Run with: `./test_install_docker.sh`

---

## Planning


### Phase 1: Core Infrastructure

#### Task 1.1: Create `vup-core` Python script [DONE]
- Location: `~/.local/bin/vup-core`
- Single executable Python file with argparse for subcommand handling
- Implement subcommands: `find`, `ls`, `validate`, `init`, `new`, `prompt`, `help`

#### Task 1.2: Create `vup` bash function [DONE]
- Location: `vup.sh` in repo (install to `~/.bash_funcs`)
- Implement subcommand routing and shell-level operations
- Helper functions: `_vup_activate`, `_vup_deactivate`

#### Task 1.3: Update `~/.bashrc`
- Define `PS1_BASE` without trailing `$`
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

#### Task 3.1: Create installation script [DONE]
- `install.sh` - Interactive installer for user installations
  - Detects all shell configs (bash, zsh, sh/other)
  - Multi-shell selection with smart defaults
  - Auto-adds PATH if needed
  - Idempotent (safe to run multiple times)
- `uninstall.sh` - Clean removal with optional shell config cleanup
- `test_install_docker.sh` - Tests installation in clean Docker container
- See `INSTALL.md` for complete documentation

#### Task 3.2: Testing [DONE]
- See the **Testing** section above for full documentation
- Run with `./test_vup_core.py && ./test_all_shells.sh`
- Multi-shell testing: bash, zsh, dash
- Docker-based installation testing

#### Task 3.3: Documentation [DONE]
- `README.md` - Project overview, features, and usage examples [DONE]
- `INSTALL.md` - Complete installation guide [DONE]
- `dev.md` - Architecture and design documentation [DONE]

---

## Open Questions

1. ~~Should `vup-core` be a single Python file or a small package?~~ **Decided:** Single file to start, can refactor later if needed.
2. ~~Where should `vup-core` be installed?~~ **Decided:** `~/.local/bin/vup-core`
3. ~~Should vup work outside of `~`?~~ **Decided:** Yes, with fallback to `~/.venv/` for most commands. Exception: `vup rm` requires being in the branch directory.
4. Color scheme for prompt venv indicator? (Deferred for now)

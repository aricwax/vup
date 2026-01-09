# vup - Python Virtual Environment Manager

## Design

### Overview

`vup` is a Python virtual environment management tool that provides intuitive venv discovery and activation based on directory context. It searches for `.venv/` directories starting from the current working directory and traversing up the filesystem tree to `~`, allowing users to activate venvs from anywhere within a project hierarchy.

### Architecture

The tool uses a hybrid bash/Python architecture:

- **Bash function (`vup`)** - The user-facing entry point, sourced into the shell via a user's `~/.bashrc` or `~/.bash_funcs` file. Handles shell-level operations that cannot be done from a subprocess:
  - Sourcing the venv `activate` script
  - Setting/restoring the `PS1` prompt
  - Deactivation
  - Routing subcommands to the Python core

- **Python script (`vup-core`)** - Handles all complex logic:
  - Directory traversal and `.venv/` discovery
  - venv validation (checking for `bin/activate`)
  - Listing all discoverable venvs
  - Creating new venvs
  - Removing venvs (with confirmation)

### Directory Structure Convention

All virtual environments are stored in hidden `.venv/` directories:

```
~/.venv/              # User-level venvs
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
5. If outside of `~`, fallback to `~/.venv/` as final check

The first valid match wins (closest to current directory takes precedence).

### Prompt Customization

When a venv is activated, the prompt is updated to show the venv identifier in the format `(<branch_dir>/<venv_name>)`:
- For `~/.venv/main` → `(~/main)`
- For `~/proj/foo/.venv/main` → `(foo/main)`

The `<branch_dir>` is the directory containing the `.venv/` folder:
- If the branch directory is `~`, display as `~`
- Otherwise, display the directory name (not full path)

The prompt format is: `(<branch_dir>/<venv_name>) BASE_PS1$ `

---

## Requirements

### R1: Activation (`vup <name>`)

**R1.1** - When `vup <name>` is called, search for a valid venv at `.venv/<name>/` starting from the current directory, and if not found, progressively traverse up to `~`, searching at each directory level.

**R1.2** - If current directory is outside of `~`, search up to the filesystem root, then check `~/.venv/` as a final fallback.

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

**R1.4** - If no valid venv is found after exhausting the search path (including `~/.venv/` fallback if applicable), print an error message.

**R1.5** - On successful activation, print a message showing which venv was activated and its location (e.g., "Activated main from ~/proj/foo/.venv/").

**R1.6** - On successful activation, update `PS1` to show the venv identifier as specified in the "Prompt Customization" section above.

**R1.7** - Disable the default venv prompt modification (`VIRTUAL_ENV_DISABLE_PROMPT=1`) to use custom prompt handling.

**R1.8** - If a venv is already active when activating a new one, implicitly deactivate the current venv first (restore `PS1`), then activate the new venv.

### R2: Directory Override (`vup -d <dir> <name>`)

**R2.1** - The `-d` flag specifies a directory for the search instead of the current directory.

**R2.2** - The `<dir>` path follows standard Linux path conventions:
- Relative paths are relative to the current working directory
- Absolute paths and paths starting with `~` are interpreted as-is
- Example: `vup -d ~/proj/foo main` activates `~/proj/foo/.venv/main`
- Example: From `/tmp`, running `vup -d dev/bar main` looks for `/tmp/dev/bar/.venv/main`

**R2.3** - The search DOES NOT traverse up from the specified directory. If the venv `<name>` does not exist or is not valid in `<dir>/.venv/`, print an error message (same validation and error behavior as R1.3/R1.4, but without upward traversal).

### R3: Listing (`vup ls [dir]`)

**R3.1** - List all discoverable venvs from the starting directory up to `~`.
- If `[dir]` is provided, start from that directory (following same path conventions as R2.2)
- If `[dir]` is omitted, start from the current directory
- If starting directory is outside `~`, fallback to listing venvs in `~/.venv/`

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

**R4.1** - If `.venv` exists in the current directory, print an error message that includes:
- Indication that `.venv` already exists
- Suggestion to use `vup new <name>` to create a new venv

**R4.2** - If `.venv` does not exist in the current directory, create it and exit silently.

### R5: Creating (`vup new <name>`)

**R5.1** - Create a new venv in the current directory's `.venv/` folder.

**R5.2** - If `.venv/` does not exist in the current directory, print an error and suggest using the `vup init` command.

**R5.3** - If `.venv/<name>` already exists, print an error indicating the venv already exists.

**R5.4** - Use `python3 -m venv .venv/<name>` to create the venv.

**R5.5** - Print success message with the full path of the created venv.

**R5.6** - After successful creation, automatically activate the new venv (following the activation behavior in R1.5 and R1.6).

### R6: Removing (`vup rm <name>`)

**R6.1** - Check for venv in current directory only (no upward tree traversal):
- If `.venv/` does not exist in current directory, print error: venvs must be removed from their branch directory
- If `.venv/<name>` does not exist, print error: venv not found in current directory's `.venv/`
- If `.venv/<name>` exists but is not a valid venv (no `bin/activate`), print error about invalid venv

**R6.2** - If venv is valid, prompt user to type the name of the venv to confirm deletion:
- An exact case-sensitive match to `<name>` proceeds with deletion
- Any other input cancels the deletion and prints a cancellation message

**R6.3** - If the venv being removed is currently active, deactivate it after confirmation but before deletion.

**R6.4** - On successful deletion, print a confirmation message.

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

**R8.3** - The validation function returns a status indicating: valid, not found, not a directory, or missing activate script.

### R9: Help (`vup help` or `vup -h` or `vup --help`)

**R9.1** - Display usage information and available subcommands.

---

## Planning

### Phase 1: Core Infrastructure

#### Task 1.1: Create `vup-core` Python script
- Location: `~/.local/bin/vup-core`
- Implement subcommands:
  - `find <name> [--start-dir <dir>] [--no-traverse]` - Search for venv, output path or error
  - `ls [--start-dir <dir>]` - List all discoverable venvs as structured output
  - `validate <path>` - Check if path is a valid venv, return status
  - `init [--dir <dir>]` - Create `.venv/` directory
  - `new <name> [--dir <dir>]` - Create a new venv
  - `prompt <venv-path>` - Output the prompt identifier for a venv path

#### Task 1.2: Create `vup` bash function
- Location: `~/.bash_funcs` (sourced by `~/.bashrc`)
- Implement:
  - Subcommand routing
  - Activation (source activate, set PS1)
  - Deactivation (restore PS1)
  - Interactive confirmation for `rm`
  - Call `vup-core` for complex operations

#### Task 1.3: Update `~/.bashrc`
- Define `BASE_PS1` without trailing `$`
- Source `~/.bash_funcs`
- Set `VIRTUAL_ENV_DISABLE_PROMPT=1`

### Phase 2: Implementation Details

#### Task 2.1: Implement search algorithm in Python
- Start from current (or specified) directory
- Walk up to `~` (or root if outside `~`)
- Fallback to `~/.venv/` if outside `~`
- Validate each candidate using `validate_venv()`
- Return first valid match or error
- Support `--no-traverse` flag for `-d` behavior

#### Task 2.2: Implement prompt generation
- Helper function to compute venv display name from path
- Extract branch directory from venv path
- Format as `<branch_dir>/<venv_name>`
- Handle `~` display for home directory

#### Task 2.3: Implement `ls` output formatting
- Traverse full search path
- Collect all venvs with metadata (name, branch dir, full path)
- Detect currently active venv via `$VIRTUAL_ENV`
- Format aligned columns with active indicator

#### Task 2.4: Implement `init`
- Check for existing `.venv/`
- Create directory or error appropriately

#### Task 2.5: Implement `new` with validation
- Check for existing `.venv/` directory
- Check for existing `.venv/<name>`
- Create venv with `python3 -m venv`

#### Task 2.6: Implement `rm`
- Validate venv exists in current `.venv/`
- Return status for bash to handle confirmation prompt
- Delete venv directory on confirmation

### Phase 3: Installation & Polish

#### Task 3.1: Create installation script
- Copy `vup-core` to `~/.local/bin/`
- Make executable
- Add `vup` function to `~/.bash_funcs`
- Update `~/.bashrc` if needed

#### Task 3.2: Testing
- Test activation from various directories
- Test edge cases (outside ~, missing .venv, invalid venvs)
- Test prompt formatting
- Test switching between venvs
- Test init/new/rm commands
- Test `vup ls` with and without directory argument

#### Task 3.3: Documentation
- Usage examples in README
- Installation instructions

---

## Open Questions

1. ~~Should `vup-core` be a single Python file or a small package?~~ **Decided:** Single file to start, can refactor later if needed.
2. ~~Where should `vup-core` be installed?~~ **Decided:** `~/.local/bin/vup-core`
3. Color scheme for prompt venv indicator? (Deferred for now)

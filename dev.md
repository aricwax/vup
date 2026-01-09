# pyve - Python Virtual Environment Manager

## Design

### Overview

`pyve` is a virtual environment management tool that provides intuitive venv discovery and activation based on directory context. It searches for `.venv/` directories starting from the current working directory and traversing up the filesystem tree to `~`, allowing users to activate venvs from anywhere within a project hierarchy.

### Architecture

The tool uses a hybrid bash/Python architecture:

- **Bash function (`pyve`)** - The user-facing entry point, sourced into the shell via `~/.bash_funcs`. Handles shell-level operations that cannot be done from a subprocess:
  - Sourcing the venv `activate` script
  - Setting/restoring the `PS1` prompt
  - Deactivation
  - Routing subcommands to the Python core

- **Python script (`pyve-core`)** - Handles all complex logic:
  - Directory traversal and `.venv/` discovery
  - Venv validation (checking for `bin/activate`)
  - Listing all discoverable venvs
  - Creating new venvs
  - Removing venvs (with confirmation)

### Directory Structure Convention

All virtual environments are stored in hidden `.venv/` directories:

```
~/.venv/              # Global/utility venvs
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

When activating a venv (e.g., `pyve main`), the tool searches for `.venv/main/` in:
1. Current directory
2. Parent directory
3. Continue up the tree...
4. `~` (home directory)
5. If outside of `~`, fallback to `~/.venv/` as final check

The first valid match wins (closest to current directory takes precedence).

### Prompt Customization

When a venv is activated, the prompt is updated to show:
- For `~/.venv/main` → `(main)`
- For `~/proj/foo/.venv/main` → `(foo/main)`

The prompt format is: `(venv_identifier) BASE_PS1$ `

---

## Requirements

### R1: Activation (`pyve <name>`)

**R1.1** - When `pyve <name>` is called, search for `.venv/<name>/` starting from the current directory and traversing up to `~`.

**R1.2** - If current directory is outside of `~`, also check `~/.venv/` as a final fallback.

**R1.3** - For each `.venv/` directory found, validate that `.venv/<name>/bin/activate` exists before considering it a match.

**R1.4** - If a `.venv/<name>/` directory exists but does not contain a valid `bin/activate`, print a warning and continue searching up the tree.

**R1.5** - If no valid venv is found after exhausting the search path, print an error message.

**R1.6** - On successful activation, print a message showing which venv was activated and its location (e.g., "Activated main from ~/proj/foo/.venv/").

**R1.7** - On successful activation, update `PS1` to show the venv identifier:
  - Global venvs (`~/.venv/<name>`) display as `(<name>)`
  - Project venvs (`<path>/.venv/<name>`) display as `(<parent_dir>/<name>)`

**R1.8** - Disable the default venv prompt modification (`VIRTUAL_ENV_DISABLE_PROMPT=1`) to use custom prompt handling.

### R2: Directory Override (`pyve -d <dir> <name>`)

**R2.1** - The `-d` flag specifies a starting directory for the search instead of the current directory.

**R2.2** - `pyve -d ~ main` should activate `~/.venv/main` regardless of current directory.

**R2.3** - The search still traverses up from the specified directory if not found there.

### R3: Listing (`pyve ls`)

**R3.1** - List all discoverable venvs from the current directory up to `~`.

**R3.2** - For each venv, display:
  - The venv name
  - The branch directory (the directory containing the `.venv/`)
  - Full path to the venv

**R3.3** - Group or visually distinguish venvs by their branch directory.

**R3.4** - Indicate which venv (if any) is currently active.

### R4: Creating (`pyve new <name>`)

**R4.1** - Create a new venv in the current directory's `.venv/` folder.

**R4.2** - If `.venv/` does not exist in the current directory, print an error and suggest using the `-f` flag.

**R4.3** - With `-f` flag (`pyve new -f <name>`), create the `.venv/` directory if it doesn't exist.

**R4.4** - Use `python3 -m venv` with `--prompt <name>` to set the venv's internal prompt name.

**R4.5** - Print success message with the full path of the created venv.

### R5: Removing (`pyve rm <name>`)

**R5.1** - Remove a venv only from the current directory's `.venv/` folder.

**R5.2** - If the current directory has no `.venv/` or the named venv doesn't exist there, print an error explaining that venvs can only be removed from their branch directory.

**R5.3** - Removal is interactive by default: prompt user to type "Yes" (exactly) to confirm deletion.

**R5.4** - Any input other than "Yes" cancels the removal and prints a message that the venv was not removed.

**R5.5** - If the venv being removed is currently active, deactivate it first.

### R6: Deactivation (`pyve off`)

**R6.1** - Deactivate the current venv if one is active.

**R6.2** - Restore `PS1` to the base prompt (without venv prefix).

**R6.3** - If no venv is active, print a message indicating there's nothing to deactivate.

### R7: Validation

**R7.1** - A `.venv/` path is only valid if it is a directory (not a file).

**R7.2** - A venv is only valid if it contains `bin/activate`.

**R7.3** - Invalid venvs are skipped with a warning during search.

### R8: Help (`pyve help` or `pyve --help`)

**R8.1** - Display usage information and available subcommands.

---

## Planning

### Phase 1: Core Infrastructure

#### Task 1.1: Create `pyve-core` Python script
- Location: `~/.local/bin/pyve-core` (or installed via this repo)
- Implement subcommands:
  - `find <name> [--start-dir <dir>]` - Search for venv, output path or error
  - `ls [--start-dir <dir>]` - List all discoverable venvs as structured output
  - `validate <path>` - Check if path is a valid venv
  - `new <name> [--force] [--dir <dir>]` - Create a new venv
  - `rm <name> [--dir <dir>]` - Remove a venv (confirmation handled in bash or via flag)

#### Task 1.2: Create `pyve` bash function
- Location: `~/.bash_funcs` (sourced by `~/.bashrc`)
- Implement:
  - Subcommand routing
  - Activation (source activate, set PS1)
  - Deactivation (restore PS1)
  - Call `pyve-core` for complex operations

#### Task 1.3: Update `~/.bashrc`
- Define `BASE_PS1` without trailing `$`
- Source `~/.bash_funcs`
- Set `VIRTUAL_ENV_DISABLE_PROMPT=1`

### Phase 2: Implementation Details

#### Task 2.1: Implement search algorithm in Python
- Start from current (or specified) directory
- Walk up to `~`
- Fallback to `~/.venv/` if outside `~`
- Validate each candidate
- Return first valid match or error

#### Task 2.2: Implement prompt generation
- Helper function to compute venv display name
- Global venvs: just the name
- Project venvs: `<parent>/<name>`

#### Task 2.3: Implement `ls` output formatting
- Traverse full search path
- Collect all venvs with metadata
- Format for display (branch directory grouping)
- Mark active venv

#### Task 2.4: Implement `new` with validation
- Check for existing `.venv/` directory
- Handle `-f` flag for directory creation
- Create venv with `--prompt` flag

#### Task 2.5: Implement `rm` with confirmation
- Validate venv exists in current `.venv/`
- Interactive "Yes" confirmation
- Handle active venv edge case

### Phase 3: Installation & Polish

#### Task 3.1: Create installation script
- Copy `pyve-core` to appropriate location
- Add `pyve` function to `~/.bash_funcs`
- Update `~/.bashrc` if needed

#### Task 3.2: Testing
- Test activation from various directories
- Test edge cases (outside ~, missing .venv, invalid venvs)
- Test prompt formatting
- Test new/rm commands

#### Task 3.3: Documentation
- Usage examples in README
- Installation instructions

---

## Open Questions

1. Should `pyve-core` be a single Python file or a small package?
2. Where should `pyve-core` be installed? (`~/.local/bin/`, as part of this repo, etc.)
3. Should we add a `pyve init` command to create `.venv/` directory (alternative to `new -f`)?
4. Color scheme for prompt venv indicator?

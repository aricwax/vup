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

When activating a venv (e.g., `vup main`), the tool searches for `.venv/main/` in:
1. Current directory
2. Parent directory
3. Continue up the tree...
4. `~` (home directory)
5. If outside of `~`, fallback to `~/.venv/` as final check

The first valid match wins (closest to current directory takes precedence).

### Prompt Customization

When a venv is activated, the prompt is updated to show:
- For `~/.venv/main` → `(~/main)`
- For `~/proj/foo/.venv/main` → `(foo/main)`
- The general format for `venv_identifier` is `(<branch_dir>/<venv_name>)`

The prompt format is: `(venv_identifier) BASE_PS1$ `

---

## Requirements

### R1: Activation (`vup <name>`)

**R1.1** - When `vup <name>` is called, search for `.venv/<name>/` starting from the current directory, and if not found, progressively traversing up to `~`, searching at each directory level.

**R1.2** - If current directory is outside of `~`, check `~/.venv/` as a final fallback.

**R1.3** - For any `.venv` found, validate that:
- `.venv` is a directory, else throw a warning that `.venv` is not a valid venv directory and continue up to next directory level
- `.venv/<name>` exists, then validate:
    - `.venv/<name>` is a directory, else throw a warning that `.venv/<name>` is not a valid venv and continue up to the next directory level
- `.venv/<name>/bin/activate` exists, else throw a warning that `.venv/<name>` does not contain a valid `bin/activate`

**R1.4** - If no valid venv is found after exhausting the search path, print an error message.

**R1.5** - On successful activation, print a message showing which venv was activated and its location (e.g., "Activated main from ~/proj/foo/.venv/").

**R1.6** - On successful activation, update `PS1` to show the venv identifier as specified in the "Prompt Customization" section above.

**R1.7** - Disable the default venv prompt modification (`VIRTUAL_ENV_DISABLE_PROMPT=1`) to use custom prompt handling.

### R2: Directory Override (`vup -d <dir> <name>`)

**R2.1** - The `-d` flag specifies a directory for the search instead of the current directory.

**R2.2** - `vup -d dev/bar main` should activate `~/dev/bar/.venv/main` regardless of current directory.

**R2.3** - The search DOES NOT traverse up from the specified directory if not found there. If the venv `<name>` does not exist in `<dir>/.venv`, then throw an error message.

### R3: Listing (`vup ls`)

**R3.1** - List all discoverable venvs from the current directory up to `~`.

**R3.2** - For each venv, display:
  - The venv name in the first column
  - The path to the branch directory (the directory containing the `.venv/`) in the second column
  - Extra trailing spaces in the first column so that it is aligned
  - Two spaces to delineate columns
  - A `*` character to indicate which venv (if any) is currently active.

Example output to `vup ls` from current directory `~/proj/foo/webscrape`:
```
  web       ~/proj/foo/webscrape
* main      ~/proj/foo
  data      ~
  main      ~
  longname  ~
```

### R4: Initializing (`vup init`)

**R4.1** - If `.venv` exists in the current directory, throw an error

**R4.2** If `.venv` does not exist in the current directory, create it and exit silently

### R5: Creating (`vup new <name>`)

**R5.1** - Create a new venv in the current directory's `.venv/` folder.

**R5.2** - If `.venv/` does not exist in the current directory, print an error and suggest using the `vup init` command.

**R5.3** - Use `python3 -m venv` with `--prompt <name>` to set the venv's internal prompt name.

**R5.4** - Print success message with the full path of the created venv.

### R6: Removing (`vup rm <name>`)

**R6.1** Follow this sequence:
- Check for venv validity only from current directory (no upward tree traversal) using `vup-validate`
- If not valid, exit and print error about venv validity
- If does not exist (`.venv/` or `.venv/<name>` does not exist) in current branch directory, exit and print error about non existence of venv and remind user that venvs must be deleted from their branch directory
- If is valid, prompt user to type the name of the venv to confirm deletion
    - An exact case-sensitive match to `<name>` deletes the venv, and a confirmation message is printed
    - Any other input cancels the deletion, and a cancelation message is printed

**R6.2** - If the venv being removed is currently active, deactivate it first.

### R7: Deactivation (`vup off`)

**R7.1** - Deactivate the current venv if one is active.

**R7.2** - Restore `PS1` to the base prompt (without venv prefix).

**R7.3** - If no venv is active, print a message indicating there's nothing to deactivate.

### R8: Validation

**R8.1** - A `.venv/` path is only valid if it is a directory (not a file).

**R8.2** - A venv is only valid if it contains `bin/activate`.

**R8.3** - Invalid venvs are skipped with a warning during search.

**R8.4** - Validation should be handled by a separate function or module `vup-validate`

### R9: Help (`vup help` or `vup -h` or `vup --help`)

**R9.1** - Display usage information and available subcommands.

---

## Planning

### Phase 1: Core Infrastructure

#### Task 1.1: Create `vup-core` Python script
- Location: `~/.local/bin/vup-core` (or installed via this repo)
- Implement subcommands:
  - `find <name> [--start-dir <dir>]` - Search for venv, output path or error
  - `ls [--start-dir <dir>]` - List all discoverable venvs as structured output
  - `validate <path>` - Check if path is a valid venv
  - `new <name> [--force] [--dir <dir>]` - Create a new venv
  - `rm <name> [--dir <dir>]` - Remove a venv (confirmation handled in bash or via flag)

#### Task 1.2: Create `vup` bash function
- Location: `~/.bash_funcs` (sourced by `~/.bashrc`)
- Implement:
  - Subcommand routing
  - Activation (source activate, set PS1)
  - Deactivation (restore PS1)
  - Call `vup-core` for complex operations

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
- Mark active venv

#### Task 2.4: Implement `new` with validation
- Check for existing `.venv/` directory
- Create venv with `--prompt` flag

#### Task 2.5: Implement `init`
#### Task 2.6: Implement `rm` with confirmation
- Validate venv exists in current `.venv/`
- Interactive confirmation
- Handle active venv edge case

### Phase 3: Installation & Polish

#### Task 3.1: Create installation script
- Copy `vup-core` to appropriate location
- Add `vup` function to `~/.bash_funcs`
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

1. Should `vup-core` be a single Python file or a small package?
2. Where should `vup-core` be installed? (`~/.local/bin/`, as part of this repo, etc.)
3. Color scheme for prompt venv indicator?

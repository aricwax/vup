#!/usr/bin/env python3
"""Tests for vup-core CLI via subprocess.

This module tests the vup-core Python script by invoking it as a subprocess,
simulating how the vup bash function calls it. Each test creates isolated
temporary directories within the user's home directory to test venv operations.

Tests cover all vup-core subcommands:
    - help: Display usage information
    - validate: Check if a path is a valid venv
    - init: Create .venv/ directory
    - new: Create a new virtual environment
    - find: Locate a venv by name (with upward traversal)
    - ls: List discoverable venvs
    - prompt: Generate shell prompt identifier

Run with: ./test_vup_core.py
"""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path

SCRIPT = Path(__file__).parent / "vup-core"
HOME = Path.home()


def run(args, cwd=None, env=None):
    """Run vup-core with the given arguments and return the result.

    This helper invokes vup-core as a subprocess, capturing stdout and stderr.
    It merges any provided environment variables with the current environment.

    Args:
        args: List of command-line arguments to pass to vup-core.
        cwd: Working directory for the subprocess (default: current directory).
        env: Additional environment variables to set (merged with os.environ).

    Returns:
        Tuple of (returncode, stdout, stderr) from the subprocess.
    """
    result = subprocess.run(
        [str(SCRIPT)] + args,
        capture_output=True,
        text=True,
        cwd=cwd,
        env={**os.environ, **(env or {})}
    )
    return result.returncode, result.stdout, result.stderr


def test_help():
    """Test that the help subcommand displays usage information.

    Verifies that 'vup-core help' exits successfully and outputs the expected
    help text including the tool description and usage examples.
    """
    code, out, err = run(["help"])
    assert code == 0, f"help failed: {err}"
    assert "vup - Python virtual environment manager" in out
    assert "vup <name>" in out
    print("PASS: help")


def test_validate_not_found():
    """Test that validate returns exit code 1 for non-existent paths.

    When given a path that doesn't exist, validate should fail with exit
    code 1 and print an appropriate error message to stderr.
    """
    code, out, err = run(["validate", "/nonexistent/path"])
    assert code == 1, "validate should fail for non-existent path"
    assert "not found" in err
    print("PASS: validate not found")


def test_validate_not_directory():
    """Test that validate returns exit code 2 when path is a file.

    Creates a temporary file and attempts to validate it as a venv.
    Should fail with exit code 2 since venvs must be directories.
    """
    with tempfile.NamedTemporaryFile() as f:
        code, out, err = run(["validate", f.name])
        assert code == 2, "validate should return 2 for non-directory"
        assert "not a directory" in err
    print("PASS: validate not directory")


def test_validate_no_activate():
    """Test that validate returns exit code 3 when bin/activate is missing.

    Creates an empty temporary directory (no bin/activate script) and
    attempts to validate it. Should fail with exit code 3.
    """
    with tempfile.TemporaryDirectory() as d:
        code, out, err = run(["validate", d])
        assert code == 3, "validate should return 3 for missing bin/activate"
        assert "missing bin/activate" in err
    print("PASS: validate no activate")


def test_validate_valid():
    """Test that validate returns exit code 0 for a valid venv structure.

    Creates a temporary directory with a bin/activate file (simulating a
    valid venv structure) and verifies that validate accepts it.
    """
    with tempfile.TemporaryDirectory() as d:
        # Create fake venv structure
        bin_dir = Path(d) / "bin"
        bin_dir.mkdir()
        (bin_dir / "activate").touch()

        code, out, err = run(["validate", d])
        assert code == 0, f"validate should pass: {err}"
    print("PASS: validate valid")


def test_init_creates_venv_dir():
    """Test that init creates a .venv directory in the current directory.

    Creates a temporary directory within HOME, runs 'vup-core init', and
    verifies that a .venv subdirectory is created.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        code, out, err = run(["init"], cwd=d)
        assert code == 0, f"init failed: {err}"
        assert (Path(d) / ".venv").is_dir()
    print("PASS: init creates .venv")


def test_init_fails_if_exists():
    """Test that init fails when .venv already exists.

    Creates a temporary directory with an existing .venv subdirectory,
    then verifies that init refuses to overwrite it and returns an error.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        (Path(d) / ".venv").mkdir()
        code, out, err = run(["init"], cwd=d)
        assert code == 1, "init should fail if .venv exists"
        assert "already exists" in err
    print("PASS: init fails if exists")


def test_new_creates_venv():
    """Test that new creates a fully functional virtual environment.

    Initializes a .venv directory, then creates a new venv named 'testvenv'.
    Verifies that the venv directory exists, contains bin/activate, and that
    the full path is output to stdout (for bash to activate).
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        # First init
        run(["init"], cwd=d)

        # Then new
        code, out, err = run(["new", "testvenv"], cwd=d)
        assert code == 0, f"new failed: {err}"

        venv_path = Path(d) / ".venv" / "testvenv"
        assert venv_path.is_dir(), "venv directory not created"
        assert (venv_path / "bin" / "activate").exists(), "activate script missing"
        assert str(venv_path) in out, "new should output venv path"
    print("PASS: new creates venv")


def test_new_fails_without_init():
    """Test that new fails when .venv directory doesn't exist.

    Attempts to create a venv without first running init. Should fail with
    an error message suggesting the user run 'vup init' first.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        code, out, err = run(["new", "testvenv"], cwd=d)
        assert code == 1, "new should fail without .venv"
        assert "vup init" in err
    print("PASS: new fails without init")


def test_new_fails_if_exists():
    """Test that new fails when a venv with the same name already exists.

    Creates a venv named 'testvenv', then attempts to create another with
    the same name. Should fail with an 'already exists' error.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "testvenv"], cwd=d)

        code, out, err = run(["new", "testvenv"], cwd=d)
        assert code == 1, "new should fail if venv exists"
        assert "already exists" in err
    print("PASS: new fails if exists")


def test_find_locates_venv():
    """Test that find locates a venv in the current directory's .venv/.

    Creates a venv named 'myvenv' and verifies that find can locate it
    when run from the same directory. The full path should be output.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "myvenv"], cwd=d)

        code, out, err = run(["find", "myvenv"], cwd=d)
        assert code == 0, f"find failed: {err}"
        assert "myvenv" in out
    print("PASS: find locates venv")


def test_find_traverses_up():
    """Test that find searches parent directories when venv isn't in cwd.

    Creates a venv in a parent directory, then runs find from a nested
    subdirectory. Verifies that find traverses upward and locates the
    venv in the ancestor directory.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        # Create venv in parent
        run(["init"], cwd=d)
        run(["new", "parentvenv"], cwd=d)

        # Create subdirectory
        subdir = Path(d) / "sub" / "deep"
        subdir.mkdir(parents=True)

        # Find from subdirectory
        code, out, err = run(["find", "parentvenv"], cwd=str(subdir))
        assert code == 0, f"find should traverse up: {err}"
        assert "parentvenv" in out
    print("PASS: find traverses up")


def test_find_no_traverse_flag():
    """Test that find --no-traverse disables upward directory search.

    Creates a venv in a parent directory, then runs find with --no-traverse
    from a subdirectory. Should fail because it only checks the current
    directory, not parents. This flag is used by 'vup -d'.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "parentvenv"], cwd=d)

        subdir = Path(d) / "sub"
        subdir.mkdir()

        # With --no-traverse, should not find parent's venv
        code, out, err = run(["find", "parentvenv", "--no-traverse"], cwd=str(subdir))
        assert code == 1, "find --no-traverse should not find parent venv"
    print("PASS: find --no-traverse")


def test_find_not_found():
    """Test that find returns an error when the venv doesn't exist.

    Attempts to find a venv named 'nonexistent' in an empty directory.
    Should fail with exit code 1 and print a 'not found' error.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        code, out, err = run(["find", "nonexistent"], cwd=d)
        assert code == 1
        assert "not found" in err
    print("PASS: find not found")


def test_ls_lists_venvs():
    """Test that ls lists all venvs in the current directory's .venv/.

    Creates two venvs named 'one' and 'two', then verifies that ls outputs
    both names in a formatted table.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "one"], cwd=d)
        run(["new", "two"], cwd=d)

        code, out, err = run(["ls"], cwd=d)
        assert code == 0, f"ls failed: {err}"
        assert "one" in out
        assert "two" in out
    print("PASS: ls lists venvs")


def test_ls_empty():
    """Test that ls returns success even when no venvs exist locally.

    Uses --start-dir to restrict the search to a specific empty directory.
    Should exit successfully with empty or minimal output.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        # Use --start-dir to only check this specific empty dir
        code, out, err = run(["ls", "--start-dir", d], cwd=d)
        assert code == 0
        # May still show home venvs if they exist, but local dir has none
    print("PASS: ls empty")


def test_ls_shows_active():
    """Test that ls marks the currently active venv with an asterisk.

    Creates a venv and simulates it being active by setting VIRTUAL_ENV
    in the environment. Verifies that the output contains '*' next to
    the active venv name.
    """
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "activevenv"], cwd=d)

        venv_path = str(Path(d) / ".venv" / "activevenv")
        code, out, err = run(["ls"], cwd=d, env={"VIRTUAL_ENV": venv_path})
        assert code == 0
        assert "*" in out
        assert "activevenv" in out
    print("PASS: ls shows active")


def test_prompt_home_venv():
    """Test that prompt generates '~/name' format for home directory venvs.

    Passes a path like ~/.venv/test to the prompt command and verifies
    that it outputs '~/test' (using ~ to indicate the home directory).
    """
    venv_path = HOME / ".venv" / "test"
    code, out, err = run(["prompt", str(venv_path)])
    assert code == 0
    assert out.strip() == "~/test"
    print("PASS: prompt home venv")


def test_prompt_project_venv():
    """Test that prompt generates 'project/name' format for project venvs.

    Passes a path like ~/myproject/.venv/dev to the prompt command and
    verifies that it outputs 'myproject/dev' (using the project directory
    name, not the full path).
    """
    venv_path = HOME / "myproject" / ".venv" / "dev"
    code, out, err = run(["prompt", str(venv_path)])
    assert code == 0
    assert out.strip() == "myproject/dev"
    print("PASS: prompt project venv")


def main():
    """Run all tests and report results.

    Iterates through all test functions, executes each one, and tracks
    pass/fail counts. Prints a summary at the end and returns 0 if all
    tests passed, 1 otherwise.
    """
    print(f"Testing vup-core at: {SCRIPT}\n")

    tests = [
        test_help,
        test_validate_not_found,
        test_validate_not_directory,
        test_validate_no_activate,
        test_validate_valid,
        test_init_creates_venv_dir,
        test_init_fails_if_exists,
        test_new_creates_venv,
        test_new_fails_without_init,
        test_new_fails_if_exists,
        test_find_locates_venv,
        test_find_traverses_up,
        test_find_no_traverse_flag,
        test_find_not_found,
        test_ls_lists_venvs,
        test_ls_empty,
        test_ls_shows_active,
        test_prompt_home_venv,
        test_prompt_project_venv,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"FAIL: {test.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"ERROR: {test.__name__}: {e}")
            failed += 1

    print(f"\n{passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    exit(main())

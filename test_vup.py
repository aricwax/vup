#!/usr/bin/env python3
"""Tests for vup-core CLI via subprocess."""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path

SCRIPT = Path(__file__).parent / "vup-core"
HOME = Path.home()

def run(args, cwd=None, env=None):
    """Run vup-core with args, return (returncode, stdout, stderr)."""
    result = subprocess.run(
        [str(SCRIPT)] + args,
        capture_output=True,
        text=True,
        cwd=cwd,
        env={**os.environ, **(env or {})}
    )
    return result.returncode, result.stdout, result.stderr


def test_help():
    """Test help subcommand."""
    code, out, err = run(["help"])
    assert code == 0, f"help failed: {err}"
    assert "vup - Python virtual environment manager" in out
    assert "vup <name>" in out
    print("PASS: help")


def test_validate_not_found():
    """Test validate on non-existent path."""
    code, out, err = run(["validate", "/nonexistent/path"])
    assert code == 1, "validate should fail for non-existent path"
    assert "not found" in err
    print("PASS: validate not found")


def test_validate_not_directory():
    """Test validate on a file (not directory)."""
    with tempfile.NamedTemporaryFile() as f:
        code, out, err = run(["validate", f.name])
        assert code == 2, "validate should return 2 for non-directory"
        assert "not a directory" in err
    print("PASS: validate not directory")


def test_validate_no_activate():
    """Test validate on directory without bin/activate."""
    with tempfile.TemporaryDirectory() as d:
        code, out, err = run(["validate", d])
        assert code == 3, "validate should return 3 for missing bin/activate"
        assert "missing bin/activate" in err
    print("PASS: validate no activate")


def test_validate_valid():
    """Test validate on a valid venv structure."""
    with tempfile.TemporaryDirectory() as d:
        # Create fake venv structure
        bin_dir = Path(d) / "bin"
        bin_dir.mkdir()
        (bin_dir / "activate").touch()

        code, out, err = run(["validate", d])
        assert code == 0, f"validate should pass: {err}"
    print("PASS: validate valid")


def test_init_creates_venv_dir():
    """Test init creates .venv directory."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        code, out, err = run(["init"], cwd=d)
        assert code == 0, f"init failed: {err}"
        assert (Path(d) / ".venv").is_dir()
    print("PASS: init creates .venv")


def test_init_fails_if_exists():
    """Test init fails if .venv already exists."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        (Path(d) / ".venv").mkdir()
        code, out, err = run(["init"], cwd=d)
        assert code == 1, "init should fail if .venv exists"
        assert "already exists" in err
    print("PASS: init fails if exists")


def test_new_creates_venv():
    """Test new creates a working venv."""
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
    """Test new fails if .venv doesn't exist (when in home)."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        code, out, err = run(["new", "testvenv"], cwd=d)
        assert code == 1, "new should fail without .venv"
        assert "vup init" in err
    print("PASS: new fails without init")


def test_new_fails_if_exists():
    """Test new fails if venv already exists."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "testvenv"], cwd=d)

        code, out, err = run(["new", "testvenv"], cwd=d)
        assert code == 1, "new should fail if venv exists"
        assert "already exists" in err
    print("PASS: new fails if exists")


def test_find_locates_venv():
    """Test find locates a venv in current directory."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        run(["init"], cwd=d)
        run(["new", "myvenv"], cwd=d)

        code, out, err = run(["find", "myvenv"], cwd=d)
        assert code == 0, f"find failed: {err}"
        assert "myvenv" in out
    print("PASS: find locates venv")


def test_find_traverses_up():
    """Test find searches parent directories."""
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
    """Test find --no-traverse doesn't search parents."""
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
    """Test find returns error for non-existent venv."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        code, out, err = run(["find", "nonexistent"], cwd=d)
        assert code == 1
        assert "not found" in err
    print("PASS: find not found")


def test_ls_lists_venvs():
    """Test ls lists venvs in search path."""
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
    """Test ls with no venvs in local dir returns success."""
    with tempfile.TemporaryDirectory(dir=HOME) as d:
        # Use --start-dir to only check this specific empty dir
        code, out, err = run(["ls", "--start-dir", d], cwd=d)
        assert code == 0
        # May still show home venvs if they exist, but local dir has none
    print("PASS: ls empty")


def test_ls_shows_active():
    """Test ls marks active venv with asterisk."""
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
    """Test prompt for home directory venv."""
    venv_path = HOME / ".venv" / "test"
    code, out, err = run(["prompt", str(venv_path)])
    assert code == 0
    assert out.strip() == "~/test"
    print("PASS: prompt home venv")


def test_prompt_project_venv():
    """Test prompt for project venv."""
    venv_path = HOME / "myproject" / ".venv" / "dev"
    code, out, err = run(["prompt", str(venv_path)])
    assert code == 0
    assert out.strip() == "myproject/dev"
    print("PASS: prompt project venv")


def main():
    """Run all tests."""
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

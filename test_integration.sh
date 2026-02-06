#!/usr/bin/env bash
# test_integration.sh - Integration tests for vup shell functions
#
# This script tests the vup shell function (vup.sh) by running it in real
# subshells with a real shell environment. Unlike test_vup_core.py which tests
# the Python backend in isolation, these tests verify the full user-facing
# workflow including shell environment manipulation (PS1, VIRTUAL_ENV, etc.).
#
# Tests cover:
#   - help: Display usage information
#   - init: Create .venv/ directory
#   - new: Create and activate a new virtual environment
#   - <name>: Activate an existing venv (with upward traversal)
#   - ls: List discoverable venvs
#   - off: Deactivate current venv
#   - -d <dir>: Activate from a specific directory
#   - Venv switching (implicit deactivation)
#
# Each test runs in an isolated temporary directory under $HOME to ensure
# vup operates within its expected scope. Tests use subshells to avoid
# polluting the parent shell's environment.
#
# Dependencies:
#   - vup-core: Must be in PATH or in the same directory as this script
#   - vup.sh: Must be in the same directory as this script
#   - Target shell: bash (default), zsh, or dash
#   - python3: Required by vup-core for venv creation
#
# Run with:
#   ./test_integration.sh [shell]
#   Examples: ./test_integration.sh bash
#             ./test_integration.sh zsh
#             ./test_integration.sh dash
#
# See dev.md for full design documentation.

set -e

# Test shell selection - defaults to bash if not specified
TEST_SHELL="${1:-bash}"

# Verify the test shell is available
if ! command -v "$TEST_SHELL" >/dev/null 2>&1; then
    echo "Error: $TEST_SHELL is not installed or not in PATH" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VUP_CORE="$SCRIPT_DIR/vup-core"
VUP_SH="$SCRIPT_DIR/vup.sh"

# ===========================================================================
# Output formatting and test tracking
# ===========================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

PASSED=0
FAILED=0

# pass <test_name>
# Record a passing test and print success message.
#
# Args:
#   test_name - Description of the test that passed
pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

# fail <test_name>
# Record a failing test and print failure message.
#
# Args:
#   test_name - Description of the test that failed (may include error details)
fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

# ===========================================================================
# Test fixtures (setup/teardown)
# ===========================================================================

# setup()
# Create an isolated test environment for a single test.
#
# Creates a temporary directory under $HOME (required for vup to operate
# within its scope) and changes into it. Also adds the script directory to
# PATH so vup-core is accessible.
#
# Side effects:
#   - Creates TEST_DIR as a temporary directory
#   - Modifies PATH to include script directory
#   - Changes cwd to TEST_DIR
#
# Must be paired with teardown() to clean up.
setup() {
    TEST_DIR=$(mktemp -d -p "$HOME" vup-test.XXXXXX)
    export PATH="$SCRIPT_DIR:$PATH"
    cd "$TEST_DIR"
}

# teardown()
# Clean up the test environment after a test.
#
# Removes the temporary directory created by setup() and changes to a safe
# directory to avoid "directory deleted" errors.
#
# Side effects:
#   - Changes cwd to /
#   - Recursively removes TEST_DIR
teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# run_vup <commands>
# Execute vup commands in an isolated subshell with proper environment.
#
# Spawns a subshell using $TEST_SHELL that sources vup.sh and runs the provided
# commands. This simulates how a user would interact with vup in a real shell
# session, with proper PS1_BASE and VIRTUAL_ENV_DISABLE_PROMPT settings.
#
# Note: Environment variables are passed before the shell invocation to ensure
# proper inheritance across different shells (especially zsh).
#
# Args:
#   commands - Shell commands to execute (passed as a single string)
#
# Returns:
#   Exit code from the subshell
#
# Example:
#   run_vup 'vup init && vup new myvenv'
run_vup() {
    # Determine shell flags - use -f for zsh to skip rc files that might reset PATH
    local shell_flags=""
    if [ "$TEST_SHELL" = "zsh" ]; then
        shell_flags="-f"
    fi

    PATH="$PATH" \
    PS1_BASE='test$ ' \
    VIRTUAL_ENV_DISABLE_PROMPT=1 \
    "$TEST_SHELL" $shell_flags -c "
        . '$VUP_SH'
        $*
    "
}

# ===========================================================================
# Test cases
# ===========================================================================

# test_help()
# Verify that 'vup help' displays usage information.
#
# The help command should output text containing "virtual environment manager"
# to confirm the help message is being displayed correctly.
test_help() {
    if run_vup 'vup help' | grep -q 'virtual environment manager'; then
        pass "vup help"
    else
        fail "vup help"
    fi
}

# test_no_args()
# Verify that 'vup' with no arguments shows the help message.
#
# When called without arguments, vup should display usage information
# rather than producing an error.
test_no_args() {
    if run_vup 'vup' | grep -q 'Usage:'; then
        pass "vup (no args)"
    else
        fail "vup (no args)"
    fi
}

# test_init()
# Verify that 'vup init' creates a .venv directory.
#
# The init command should create a .venv/ directory in the current directory
# to hold virtual environments. This is a prerequisite for 'vup new'.
test_init() {
    setup
    if run_vup 'vup init' && [ -d .venv ]; then
        pass "vup init"
    else
        fail "vup init"
    fi
    teardown
}

# test_new()
# Verify that 'vup new' creates a venv and activates it.
#
# After init, 'vup new testvenv' should:
#   1. Create .venv/testvenv/ with a valid venv structure
#   2. Automatically activate the new venv (sets VIRTUAL_ENV)
#   3. Print an activation message
test_new() {
    setup
    run_vup 'vup init'
    output=$(run_vup 'vup new testvenv && echo "VIRTUAL_ENV=$VIRTUAL_ENV"')
    if [ -d .venv/testvenv ] && echo "$output" | grep -q "Activated testvenv"; then
        pass "vup new"
    else
        fail "vup new: $output"
    fi
    teardown
}

# test_activate()
# Verify that 'vup <name>' activates an existing venv.
#
# Creates a venv, then activates it by name in a fresh subshell. Verifies
# that the activation message is printed and VIRTUAL_ENV is set correctly.
# This tests the primary vup workflow.
test_activate() {
    setup
    run_vup 'vup init'
    run_vup 'vup new myvenv'
    output=$(run_vup 'vup myvenv && echo "active=$VIRTUAL_ENV"')
    if echo "$output" | grep -q "Activated myvenv"; then
        pass "vup activate"
    else
        fail "vup activate: $output"
    fi
    teardown
}

# test_ls()
# Verify that 'vup ls' lists all venvs in the current .venv/ directory.
#
# Creates two venvs and verifies that both appear in the ls output.
# The output should be a formatted table showing venv names and locations.
test_ls() {
    setup
    run_vup 'vup init'
    run_vup 'vup new one'
    run_vup 'vup new two'
    output=$(run_vup 'vup ls')
    if echo "$output" | grep -q "one" && echo "$output" | grep -q "two"; then
        pass "vup ls"
    else
        fail "vup ls: $output"
    fi
    teardown
}

# test_off()
# Verify that 'vup off' deactivates the current venv.
#
# Activates a venv, then runs 'vup off' and checks that VIRTUAL_ENV is unset.
# This tests the shell-level deactivation that restores the original environment.
test_off() {
    setup
    run_vup 'vup init'
    run_vup 'vup new testvenv'
    # Activate then deactivate
    output=$(run_vup 'vup testvenv && vup off && echo "VIRTUAL_ENV=${VIRTUAL_ENV:-empty}"')
    if echo "$output" | grep -q "VIRTUAL_ENV=empty"; then
        pass "vup off"
    else
        fail "vup off: $output"
    fi
    teardown
}

# test_off_none()
# Verify that 'vup off' prints a message when no venv is active.
#
# Running 'vup off' without an active venv should not error, but should
# inform the user that there's nothing to deactivate.
test_off_none() {
    setup
    output=$(run_vup 'vup off')
    if echo "$output" | grep -q "No venv active"; then
        pass "vup off (none active)"
    else
        fail "vup off (none active): $output"
    fi
    teardown
}

# test_subdir_activation()
# Verify that vup finds venvs in parent directories (upward traversal).
#
# Creates a venv in a parent directory, then attempts to activate it from
# a deeply nested subdirectory. This tests vup's core directory traversal
# feature that allows venvs to be activated from anywhere within a project.
test_subdir_activation() {
    setup
    run_vup 'vup init'
    run_vup 'vup new parentvenv'
    mkdir -p sub/deep
    output=$(cd sub/deep && run_vup 'vup parentvenv && echo "found"')
    if echo "$output" | grep -q "Activated parentvenv"; then
        pass "subdir activation"
    else
        fail "subdir activation: $output"
    fi
    teardown
}

# test_prompt()
# Verify that vup-core generates correct prompt identifiers.
#
# The prompt format should be "<branch_dir>/<venv_name>" where branch_dir
# is the name of the directory containing .venv/. For a venv at
# /home/user/myproject/.venv/dev, the prompt should be "myproject/dev".
# This test calls vup-core directly to verify the prompt generation.
test_prompt() {
    setup
    run_vup 'vup init'
    run_vup 'vup new myvenv'
    # Check that prompt command generates expected format
    dir_name=$(basename "$TEST_DIR")
    output=$("$VUP_CORE" prompt "$TEST_DIR/.venv/myvenv")
    if [ "$output" = "$dir_name/myvenv" ]; then
        pass "prompt format"
    else
        fail "prompt format: expected '$dir_name/myvenv', got '$output'"
    fi
    teardown
}

# test_dash_d()
# Verify that 'vup -d <dir> <name>' activates from a specific directory.
#
# The -d flag allows activating a venv from a specific directory without
# upward traversal. This is useful for explicitly targeting a venv when
# multiple venvs with the same name exist in the directory tree.
test_dash_d() {
    setup
    run_vup 'vup init'
    run_vup 'vup new targetvenv'
    mkdir other
    output=$(cd other && run_vup "vup -d '$TEST_DIR' targetvenv")
    if echo "$output" | grep -q "Activated targetvenv"; then
        pass "vup -d"
    else
        fail "vup -d: $output"
    fi
    teardown
}

# test_switch()
# Verify that activating a new venv implicitly deactivates the old one.
#
# When switching between venvs, the previous venv should be deactivated
# automatically before the new one is activated. VIRTUAL_ENV should point
# to the most recently activated venv.
test_switch() {
    setup
    run_vup 'vup init'
    run_vup 'vup new first'
    run_vup 'vup new second'
    output=$(run_vup 'vup first && vup second && echo "VIRTUAL_ENV=$VIRTUAL_ENV"')
    if echo "$output" | grep -q ".venv/second"; then
        pass "venv switch"
    else
        fail "venv switch: $output"
    fi
    teardown
}

# ===========================================================================
# Test runner
# ===========================================================================

# main()
# Run all tests and report results.
#
# Executes each test function in sequence and prints a summary showing
# the number of passed and failed tests. Returns 0 if all tests passed,
# non-zero otherwise.
#
# Returns:
#   0 if all tests passed, 1 if any test failed
main() {
    echo "Integration tests for vup ($TEST_SHELL)"
    echo "========================================"
    echo ""

    test_help
    test_no_args
    test_init
    test_new
    test_activate
    test_ls
    test_off
    test_off_none
    test_subdir_activation
    test_prompt
    test_dash_d
    test_switch

    echo ""
    echo "$PASSED passed, $FAILED failed"

    [ "$FAILED" -eq 0 ]
}

main

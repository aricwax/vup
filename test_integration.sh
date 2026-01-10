#!/bin/bash
# Integration tests for vup bash function
# Tests the full workflow in a real shell environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VUP_CORE="$SCRIPT_DIR/vup-core"
VUP_BASH="$SCRIPT_DIR/vup.bash"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

# Create a test environment
setup() {
    TEST_DIR=$(mktemp -d -p "$HOME" vup-test.XXXXXX)
    export PATH="$SCRIPT_DIR:$PATH"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Run a command in a subshell with vup loaded
run_vup() {
    bash -c "
        export BASE_PS1='test$ '
        export VIRTUAL_ENV_DISABLE_PROMPT=1
        source '$VUP_BASH'
        $*
    "
}

# Test: vup help works
test_help() {
    if run_vup 'vup help' | grep -q 'virtual environment manager'; then
        pass "vup help"
    else
        fail "vup help"
    fi
}

# Test: vup with no args shows help
test_no_args() {
    if run_vup 'vup' | grep -q 'Usage:'; then
        pass "vup (no args)"
    else
        fail "vup (no args)"
    fi
}

# Test: vup init creates .venv
test_init() {
    setup
    if run_vup 'vup init' && [[ -d .venv ]]; then
        pass "vup init"
    else
        fail "vup init"
    fi
    teardown
}

# Test: vup new creates and activates venv
test_new() {
    setup
    run_vup 'vup init'
    output=$(run_vup 'vup new testvenv && echo "VIRTUAL_ENV=$VIRTUAL_ENV"')
    if [[ -d .venv/testvenv ]] && echo "$output" | grep -q "Activated testvenv"; then
        pass "vup new"
    else
        fail "vup new: $output"
    fi
    teardown
}

# Test: vup <name> activates existing venv
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

# Test: vup ls lists venvs
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

# Test: vup off deactivates
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

# Test: vup off with no active venv
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

# Test: activation from subdirectory finds parent venv
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

# Test: prompt shows correct format
test_prompt() {
    setup
    run_vup 'vup init'
    run_vup 'vup new myvenv'
    # Check that prompt command generates expected format
    dir_name=$(basename "$TEST_DIR")
    output=$("$VUP_CORE" prompt "$TEST_DIR/.venv/myvenv")
    if [[ "$output" == "$dir_name/myvenv" ]]; then
        pass "prompt format"
    else
        fail "prompt format: expected '$dir_name/myvenv', got '$output'"
    fi
    teardown
}

# Test: vup -d activates from specific directory
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

# Test: switching venvs deactivates old one
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

# Run all tests
main() {
    echo "Integration tests for vup"
    echo "========================="
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

    [[ $FAILED -eq 0 ]]
}

main

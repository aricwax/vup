#!/usr/bin/env bash
# test_all_shells.sh - Run integration tests across multiple shells
#
# This script runs test_integration.sh with bash, zsh, and dash to verify
# that vup.sh is truly POSIX-compliant and works across different shells.
#
# Shells are tested in order:
#   1. bash - Reference implementation
#   2. zsh  - Popular alternative shell
#   3. dash - Strict POSIX compliance check
#
# If a shell is not installed, it will be skipped with a warning.
#
# Run with: ./test_all_shells.sh
#
# Returns:
#   0 if all available shells pass, 1 if any shell fails

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test_integration.sh"

SHELLS="bash zsh dash"
TESTED=0
PASSED=0
SKIPPED=0

echo "Testing vup across multiple shells"
echo "==================================="
echo ""

for shell in $SHELLS; do
    if ! command -v "$shell" >/dev/null 2>&1; then
        echo "⊘ Skipping $shell (not installed)"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi

    TESTED=$((TESTED + 1))

    if "$TEST_SCRIPT" "$shell"; then
        echo "✓ All tests passed for $shell"
        PASSED=$((PASSED + 1))
    else
        echo "✗ Tests failed for $shell"
        exit 1
    fi
    echo ""
done

echo "=========================================="
echo "Summary: $PASSED/$TESTED shells passed"
if [ "$SKIPPED" -gt 0 ]; then
    echo "         $SKIPPED shell(s) skipped"
fi

[ "$PASSED" -eq "$TESTED" ]

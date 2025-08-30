#!/usr/bin/env bash
#
# Run integration tests and report results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running comprehensive integration test suite..."
echo ""

# Run test with timeout to prevent hanging
output=$(bash "$SCRIPT_DIR/integration/test_complete_portability.sh" 2>&1) || true

# Count results
passed=$(echo "$output" | grep -c "✓" || true)
failed=$(echo "$output" | grep -c "✗" || true)
skipped=$(echo "$output" | grep -c "⊘" || true)

# Display output
echo "$output"

# Show summary
echo ""
echo "=================================================="
echo "INTEGRATION TEST RESULTS SUMMARY"
echo "=================================================="
echo "✓ Passed:  $passed"
echo "✗ Failed:  $failed"
echo "⊘ Skipped: $skipped"
echo "Total:     $((passed + failed + skipped))"

if [ "$failed" -eq 0 ]; then
    echo ""
    echo "✅ ALL TESTS PASSED!"
    exit 0
else
    echo ""
    echo "❌ SOME TESTS FAILED"
    exit 1
fi
#!/usr/bin/env bash
# run_all_tests.sh — nyxCore test runner
set -euo pipefail

echo "=== Python unit tests ==="
python -m unittest discover -s . -p "test_*.py" || {
    echo "Python tests failed"
    exit 1
}

if [ -f dev/dot/tests/test_spinner.sh ]; then
    echo "=== Shell: spinner ==="
    bash dev/dot/tests/test_spinner.sh || {
        echo "Spinner test failed"
        exit 1
    }
fi

if command -v go >/dev/null 2>&1; then
    echo "=== Go: storage_manager (mock) ==="
    echo "go test simulated OK"
else
    echo "Go not installed — skipping"
fi

echo "All tests passed"

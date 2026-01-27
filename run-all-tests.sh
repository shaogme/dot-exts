#!/usr/bin/env bash
set -e

if ! command -v nix &> /dev/null; then
    echo "Error: 'nix' command not found. Please install Nix to run these tests."
    exit 1
fi

echo "============================================"
echo "Starting global test runner..."
echo "============================================"

# Find all run-tests.sh excluding this script if it was named similarly
# and execute them.
find . -name "run-tests.sh" -type f | while read -r script; do
    # Skip if it's not actually executable or in a weird place,
    # but based on the request we just run them.
    echo ""
    echo ">>> Found test: $script"
    
    # Ensure it is executable
    chmod +x "$script"
    
    # Execute the script. We use a subshell to avoid directory change issues if the scripts cd around.
    # However, most scripts expect to be run from their parent or handle their own path.
    # Based on kernel/cachyos/tests/run-tests.sh, it handles TEST_DIR="$(dirname "$0")".
    (
        "$script"
    )
    
    if [ $? -ne 0 ]; then
        echo "FAIL: $script failed with exit code $?"
        exit 1
    fi
done

echo ""
echo "============================================"
echo "All discovered tests passed!"
echo "============================================"

#!/usr/bin/env bash
set -e

# Navigate to the directory of this script to run flake commands
cd "$(dirname "$0")"

echo "Checking Flake integration..."

# Check if the flake configuration evaluates and describes a valid build
# Using --dry-run to check for validity without waiting for full compilation
# This confirms that:
# 1. Inputs are resolved correctly (path:../../)
# 2. Modules are imported correctly
# 3. Kernel and Btrfs configurations are valid and don't conflict
# 4. Top-level derivation can be instantiated

# Clean up previous results if any
rm -f result
# Remove flake.lock to avoid "unlocked input" errors with path inputs
rm -f flake.lock


nix build .#nixosConfigurations.testMachine.config.system.build.toplevel --dry-run --show-trace \
  --extra-experimental-features flakes \
  --no-write-lock-file \
  --option substituters "$CACHE_Substituters" \
  --option trusted-public-keys "$CACHE_TrustedPublicKeys" \
  --allow-dirty

echo "Flake integration check passed: Top-level derivation is valid."

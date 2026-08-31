#!/usr/bin/env bash
set -e

TEST_DIR="$(dirname "$0")"

echo "============================================"
echo "Running Disk Config (Btrfs) Tests"
echo "============================================"

echo ""
echo "[1/2] Running Static Configuration Checks..."
# 构建 staticCheck 属性
nix-build "$TEST_DIR" -A staticCheck
echo "Static checks passed."

echo ""
echo "[2/2] Running System Build Test (Dry Run/Instantiation)..."
echo "Building system configuration..."
nix-build "$TEST_DIR" -A buildTest

echo ""
echo "============================================"
echo "All Disk Config Tests Passed Successfully!"
echo "============================================"

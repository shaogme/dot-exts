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
# 为了节省时间，我们通常只做 drv 实例化测试，或者真正构建
# 如果要真正构建，去掉 --dry-run
# 这里我们尝试完整构建，因为它只是一个配置，只要不部署，通常不会太慢（除非内核也要编）
echo "Building system configuration..."
nix-build "$TEST_DIR" -A buildTest

echo ""
echo "============================================"
echo "All Disk Config Tests Passed Successfully!"
echo "============================================"

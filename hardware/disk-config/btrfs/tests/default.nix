{ pkgs ? import <nixpkgs> {} }:

let
  btrfsTest = import ./test-btrfs.nix { inherit pkgs; };
  lib = pkgs.lib;

  # Define checks
  check = name: condition:
    if condition then
      builtins.trace "PASS: ${name}" true
    else
      abort "FAIL: ${name}";

  # Evaluate all static checks
  allChecks = [
    (check "Btrfs Module - Root Filesystem (/)" btrfsTest.hasRootFs)
    (check "Btrfs Module - Home Filesystem (/home)" btrfsTest.hasHomeFs)
    (check "Btrfs Module - Nix Filesystem (/nix)" btrfsTest.hasNixFs)
    (check "Btrfs Module - Image Size Calculation" (btrfsTest.imageSizeCheck == "7168M"))
    (check "Btrfs Module - Disko Config Generated" (btrfsTest.diskoConfig != null))
  ];

in
{
  # 1. 静态检查任务：构建这个 derivation 会运行所有的 assert 检查
  staticCheck = pkgs.runCommand "disk-config-static-check" {} ''
    echo "Evaluating Static Checks..."
    echo "Checks result: ${toString allChecks}"
    echo "Verifying generated Disko script syntax..."
    echo "${btrfsTest.diskoScript}" > /dev/null
    echo "All static checks passed!"
    touch $out
  '';

  # 2. 构建测试任务：尝试构建整个系统配置，确保没有底层构建错误
  # 这比静态检查更重，会下载/编译所有依赖
  buildTest = btrfsTest.toplevel;
}

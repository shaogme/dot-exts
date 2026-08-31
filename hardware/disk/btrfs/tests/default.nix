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
    # 1. 单分区多子卷检查
    (check "Subvols - Root Filesystem (/)" btrfsTest.subvols.hasRootFs)
    (check "Subvols - Home Filesystem (/home)" btrfsTest.subvols.hasHomeFs)
    (check "Subvols - Nix Filesystem (/nix)" btrfsTest.subvols.hasNixFs)
    (check "Subvols - Log Filesystem (/var/log)" btrfsTest.subvols.hasLogFs)
    (check "Subvols - Log Needed For Boot" btrfsTest.subvols.isLogNeededForBoot)
    (check "Subvols - Image Size Calculation" (btrfsTest.subvols.imageSizeCheck == "7168M"))
    (check "Subvols - Disko Config Generated" (btrfsTest.subvols.diskoConfig != null))

    # 2. 多分区独立拆分检查
    (check "Split - Root Filesystem (/)" btrfsTest.split.hasRootFs)
    (check "Split - Home Filesystem (/home)" btrfsTest.split.hasHomeFs)
    (check "Split - Nix Filesystem (/nix)" btrfsTest.split.hasNixFs)
    (check "Split - Root Partition Size (10G)" (btrfsTest.split.rootPartSize == "10G"))
    (check "Split - Nix Partition Size (30G)" (btrfsTest.split.nixPartSize == "30G"))
    (check "Split - Home Partition Size (100%)" (btrfsTest.split.homePartSize == "100%"))
    (check "Split - Image Size Calculation" (btrfsTest.split.imageSizeCheck == "63488M"))
    (check "Split - Disko Config Generated" (btrfsTest.split.diskoConfig != null))
  ];

in
{
  # 静态检查任务：运行所有 assert 检查和 Disko 脚本生成测试（不进行全量系统编译）
  staticCheck = pkgs.runCommand "disk-static-check" {} ''
    echo "Evaluating Static Checks..."
    echo "Checks result: ${toString allChecks}"
    echo "Verifying generated Disko scripts..."
    echo "${btrfsTest.subvols.diskoScript}" > /dev/null
    echo "${btrfsTest.split.diskoScript}" > /dev/null
    echo "All static checks passed!"
    touch $out
  '';

  # 2. 构建测试任务：尝试构建整个系统配置，确保没有底层构建错误
  # 这比静态检查更重，会下载/编译所有依赖
  buildTest = btrfsTest.toplevel;
}

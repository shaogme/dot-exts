{ pkgs ? import <nixpkgs> {} }:

let
  # 导入库入口
  repo = import ../../../../default.nix { inherit pkgs; };
  
  # 获取 NixOS 系统评估工具
  evalConfig = import (pkgs.path + "/nixos/lib/eval-config.nix");

  # 定义测试用的 NixOS 配置
  testSystem = evalConfig {
    system = "x86_64-linux";
    modules = [
      # 导入我们要测试的模块
      repo.hardware.disk-config.btrfs.nixosModule

      # 基础配置
      ({ config, lib, ... }: {
        # 启用模块
        # 启用模块
        exts.hardware.disk.enable = true;
        exts.hardware.disk.device = "/dev/vda";
        exts.hardware.disk.swapSize = 4096;
        exts.hardware.disk.imageBaseSize = 3072;

        # 设置 stateVersion 以避免警告
        system.stateVersion = "23.11";
        
        # 模拟必要的硬件配置（通常由 nixos-generate-config 生成）
        boot.loader.grub.enable = lib.mkForce true; # 确保 grub 启用逻辑不冲突
      })
    ];
  };

in
  # 我们返回一个属性集，包含几个关键的检查点
  {
    # 1. 检查生成的 fileSystems 是否包含预期的挂载点
    hasRootFs = builtins.hasAttr "/" testSystem.config.fileSystems;
    hasHomeFs = builtins.hasAttr "/home" testSystem.config.fileSystems;
    hasNixFs = builtins.hasAttr "/nix" testSystem.config.fileSystems;
    
    # 2. 检查生成的 disko 配置是否存在
    diskoConfig = testSystem.config.disko.devices.disk.main;
    
    # 3. 我们可以尝试构建 disko 脚本（这不会构建 VM，只是生成脚本）
    diskoScript = testSystem.config.system.build.diskoScript or null; 
    
    # 4. 验证 Swap 大小计算是否正确
    imageSizeCheck = testSystem.config.disko.devices.disk.main.imageSize;

    # 5. 完整的系统构建目标 (Toplevel)
    toplevel = testSystem.config.system.build.toplevel;
  }

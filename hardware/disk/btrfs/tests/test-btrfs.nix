{ pkgs ? import <nixpkgs> {} }:

let
  # 导入库入口
  repo = import ../../../../default.nix { inherit pkgs; };
  
  # 获取 NixOS 系统评估工具
  evalConfig = import (pkgs.path + "/nixos/lib/eval-config.nix");

  # 用例 1: 单分区多子卷模式（现有主机模式）
  testSystemSubvols = evalConfig {
    system = "x86_64-linux";
    modules = [
      repo.hardware.disk.btrfs.nixosModule
      ({ config, lib, ... }: {
        exts.hardware.disk.btrfs = {
          enable = true;
          device = "/dev/vda";
          swapSize = 4096;
          imageBaseSize = 3072;
          partitions.root = {
            size = "100%";
            subvolumes = {
              "@" = { mountpoint = "/"; };
              "@home" = { mountpoint = "/home"; };
              "@nix" = { mountpoint = "/nix"; };
              "@log" = { mountpoint = "/var/log"; neededForBoot = true; };
            };
          };
        };

        system.stateVersion = "23.11";
        boot.loader.grub.enable = lib.mkForce true;
      })
    ];
  };

  # 用例 2: 多分区独立拆分模式（各分区自定义大小）
  testSystemSplit = evalConfig {
    system = "x86_64-linux";
    modules = [
      repo.hardware.disk.btrfs.nixosModule
      ({ config, lib, ... }: {
        exts.hardware.disk.btrfs = {
          enable = true;
          device = "/dev/nvme0n1";
          swapSize = 2048;
          imageBaseSize = 61440;
          partitions = {
            root = {
              size = "10G";
              mountpoint = "/";
            };
            nix = {
              size = "30G";
              mountpoint = "/nix";
            };
            home = {
              size = "100%";
              mountpoint = "/home";
            };
          };
        };

        system.stateVersion = "23.11";
        boot.loader.grub.enable = lib.mkForce true;
      })
    ];
  };

in
{
  # 1. 单分区多子卷检查点
  subvols = {
    hasRootFs = builtins.hasAttr "/" testSystemSubvols.config.fileSystems;
    hasHomeFs = builtins.hasAttr "/home" testSystemSubvols.config.fileSystems;
    hasNixFs = builtins.hasAttr "/nix" testSystemSubvols.config.fileSystems;
    hasLogFs = builtins.hasAttr "/var/log" testSystemSubvols.config.fileSystems;
    isLogNeededForBoot = testSystemSubvols.config.fileSystems."/var/log".neededForBoot or false;
    diskoConfig = testSystemSubvols.config.disko.devices.disk.main;
    imageSizeCheck = testSystemSubvols.config.disko.devices.disk.main.imageSize;
    diskoScript = testSystemSubvols.config.system.build.diskoScript or null;
  };

  # 2. 多分区拆分检查点
  split = {
    hasRootFs = builtins.hasAttr "/" testSystemSplit.config.fileSystems;
    hasHomeFs = builtins.hasAttr "/home" testSystemSplit.config.fileSystems;
    hasNixFs = builtins.hasAttr "/nix" testSystemSplit.config.fileSystems;
    rootPartSize = testSystemSplit.config.disko.devices.disk.main.content.partitions.root.size;
    nixPartSize = testSystemSplit.config.disko.devices.disk.main.content.partitions.nix.size;
    homePartSize = testSystemSplit.config.disko.devices.disk.main.content.partitions.home.size;
    diskoConfig = testSystemSplit.config.disko.devices.disk.main;
    imageSizeCheck = testSystemSplit.config.disko.devices.disk.main.imageSize;
    diskoScript = testSystemSplit.config.system.build.diskoScript or null;
  };

  # 3. 完整的系统构建目标 (Toplevel)
  toplevel = testSystemSubvols.config.system.build.toplevel;
}

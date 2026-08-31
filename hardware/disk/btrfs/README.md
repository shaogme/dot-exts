# 磁盘配置模块 (Disk Configuration)

本模块位于 `hardware/disk/btrfs`，提供基于 [disko](https://github.com/nix-community/disko) 的标准化声明式磁盘布局方案。旨在简化 NixOS 的磁盘配置过程，支持灵活自定义各分区大小与显式卷拆分。

## Btrfs 布局方案 (`hardware.disk.btrfs`)

这是一个针对现代系统优化的通用 Btrfs 声明式布局模块，包含以下特性：

*   **分区结构支持**：
    *   **Boot (EF02)**: 可选 1MB，用于 BIOS 兼容启动。
    *   **ESP (EFI System Partition)**: 可选 32MB（或自定义），挂载于 `/boot/efi`。
    *   **Swap (可选)**: 仅当配置了 swap 大小时自动创建对应交换分区。
    *   **声明式 Partitions**: 允许用户显式声明任意分区及其大小、挂载点和 Btrfs 子卷。
*   **常见布局形态**：
    1. **多分区独立拆分模式（各分区自定义大小）**：例如将 `/nix`（30G）、`/`（10G）、`/home`（100%）拆分为独立 GPT 分区。
    2. **单分区多子卷模式**：在单个 `root` 分区内创建 `@`、`@home`、`@nix`、`@log` 等子卷共享存储池。
*   **优化特性**：
    *   默认启用 `zstd:3` 透明压缩 (`compress-force=zstd:3`)。
    *   默认启用 `noatime` 减少写入。
    *   默认启用 `space_cache=v2` 提升性能。
    *   **自动扩容**：系统首次启动时会自动修复 GPT 分区表并扩容末尾分区 (`boot.growPartition = true`)。
    *   **引导加载器**：默认配置 GRUB (`efiSupport = true`, `efiInstallAsRemovable = true`) 并禁用 systemd-boot。

## 配置示例

### 1. 多分区独立拆分方案（自定义各卷大小）

```nix
exts.hardware.disk.btrfs = {
  enable = true;
  device = "/dev/vda";
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
```

### 2. 单分区多子卷方案（VPS 标准布局）

```nix
exts.hardware.disk.btrfs = {
  enable = true;
  device = "/dev/vda";
  swapSize = 2048;
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
```

### 3. disko-entrypoint.nix (双模式入口示例)

```nix
{ pkgs ? import <nixpkgs> { }, modulesPath ? null, ... }:

if modulesPath != null then
  let
    sources = import ./npins;
    dot-exts = import sources.dot-exts { inherit pkgs; };
  in
  {
    imports = [
      dot-exts.hardware.disk.btrfs.nixosModule
    ];

    config.exts.hardware.disk.btrfs = {
      enable = true;
      device = "/dev/sda";
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
  }
else
  {
    disko.devices = (import ./host/default.nix).config.disko.devices;
  }
```
 
**configuration.nix (配置示例)**:
 
```nix
{ config, pkgs, ... }:
{
  imports = [
    ./disko-entrypoint.nix
    # ... 其他模块 imports
  ];
 
  # ... 系统基础配置
  system.stateVersion = "24.05";
  networking.hostName = "nixos-machine";
 
  boot.loader.grub.enable = true;
}
```
 
**安装与构建指令**：
 
```bash
# 1. 使用 disko 命令行工具进行分区 (Mode 2)
# 这会读取 host/default.nix -> configuration.nix -> disko-entrypoint.nix (Mode 1) -> 生成分区配置
sudo disko --mode disko disko-entrypoint.nix
 
# 2. 构建系统并安装到挂载点 /mnt
sudo nixos-install --root /mnt --system $(nix-build host/default.nix -A system --no-out-link)
```

## 测试模式 (`exts.testMode`)

为了方便在 CI 环境或虚拟机中进行配置验证而无需进行真实的磁盘分区，本模块支持全局 `exts.testMode` 选项。

*   **启用方式**: 在系统配置中设置 `exts.testMode = true;`。
*   **行为变化**:
    *   **禁用 Disko**: 不再定义 `disko.devices`，防止 `disko` 尝试格式化磁盘。
    *   **禁用引导加载程序**: 自动关闭 GRUB 和 EFI 相关配置，避免在非物理环境下安装引导失败。
    *   **保留驱动**: 依然保留 `boot.supportedFilesystems = [ "btrfs" ]` 等基础环境支持。
*   **适用场景**: 仅需要验证配置能否通过 Nix 评估（Eval），或者在已经分好区的环境中运行测试。

## 测试 (Testing)

该模块包含一套自动化测试套件，用于确保磁盘布局逻辑的准确性和配置的可构建性。

### 运行测试

在仓库根目录下，执行脚本运行完整测试套件：

```bash
./hardware/disk/btrfs/tests/run-tests.sh
```

该脚本会依次执行两个阶段：

1.  **静态配置检查 (Static Checks)**: 快速验证挂载点、Disko 配置语法以及分区大小计算逻辑。
2.  **系统构建测试 (Build Test)**: 尝试实例化整个 NixOS 系统配置，确保模块与 NixOS 标准库完全兼容。

### 详细测试项

测试套件通过 `tests/test-btrfs.nix` 定义，涵盖了以下验证点：

*   **挂载点校验**: 确保 `/`、`/home` 和 `/nix` 正确映射到了 Btrfs 子卷。
*   **Disko 配置生成**: 验证配置评估后是否生成了合法的 Disko 设备定义。
*   **镜像大小计算**: 验证 `imageSize` 是否根据 `swapSize` 和基础镜像空间正确累加。
*   **构建可行性**: 确保 `system.build.toplevel` 可以成功实例化，无变量冲突。

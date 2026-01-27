# 磁盘配置模块 (Disk Configuration)

本模块位于 `hardware/disk-config/btrfs`，提供基于 [disko](https://github.com/nix-community/disko) 的标准化磁盘布局方案。旨在简化 NixOS 的磁盘配置过程，开箱即用。

## Btrfs 布局方案 (`hardware.disk-config.btrfs`)

这是一个针对现代系统优化的通用 Btrfs 布局，包含以下特性：

*   **分区结构**：
    *   **Boot (EF02)**: 1MB，用于 BIOS 兼容启动。
    *   **ESP (EFI System Partition)**: 32MB，挂载于 `/boot/efi`。
    *   **Swap (可选)**: 仅当配置了 swap 大小时自动创建。
    *   **Root (Btrfs)**: 占据生剩余所有空间。
*   **Btrfs 子卷 (Subvolumes)**：
    *   `@` -> `/` (根目录)
    *   `@home` -> `/home`
    *   `@nix` -> `/nix`
    *   `@log` -> `/var/log`
*   **优化特性**：
    *   启用 `zstd:3` 透明压缩 (`compress-force=zstd:3`)。
    *   启用 `noatime` 减少写入。
    *   启用 `space_cache=v2` 提升性能。
    *   **自动扩容**：系统首次启动时会自动修复 GPT 分区表并扩容根分区 (`boot.growPartition = true`)。
    *   **引导加载器**：默认配置 GRUB (`efiSupport = true`, `efiInstallAsRemovable = true`) 并禁用 systemd-boot。

## 使用说明

### 1. 引入模块
 
您可以选择通过 Flakes 或传统方式引入此模块。
 
#### 选项 A: Flake 方式 (推荐)
 
在 `flake.nix` 中：
 
```nix
{
  inputs.dot-exts.url = "github:shaogme/dot-exts";
 
  outputs = { self, nixpkgs, dot-exts, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      # ...
      modules = [
        dot-exts.nixosModules.disk-btrfs
 
        # 或者通过 dot-exts.nixosModules.default 引入所有模块
      ];
    };
  };
}
```
 
#### 选项 B: 传统方式 (npins)
 
推荐使用 `npins` 来管理依赖，替代传统的 `fetchTarball` 或 `git submodule`。
 
1. 初始化并添加本仓库依赖：
 
```bash
npins init
npins add github -b main shaogme dot-exts
```
 
2. 在像配置中引入：
 
```nix
{ pkgs, ... }:
let
  sources = import ./npins;
  # 获取 dot-exts 仓库实例
  dot-exts = import sources.dot-exts { inherit pkgs; };
in
{
  imports = [
    # 导入 Btrfs 磁盘配置模块
    dot-exts.hardware.disk-config.btrfs.nixosModule
  ];
 
  # ... 其他配置
}
```

### 3. npins 方式完整安装示例

以下展示了通过 standard 方式（非 Flake），结合 `npins` 管理依赖并使用 `disko-entrypoint.nix` 进行部署的完整流程。
 
这种方式允许文件既作为 NixOS 模块被引入，又可以被 `disko` CLI 直接调用以执行分区。
 
**disko-entrypoint.nix (双模式入口)**:
 
```nix
{ pkgs ? import <nixpkgs> { }, modulesPath ? null, ... }:
 
if modulesPath != null then
  # ---------------------------------------------------------
  # Mode 1: NixOS Module (Imported by configuration.nix)
  # ---------------------------------------------------------
  let
    sources = import ./npins;
    dot-exts = import sources.dot-exts { inherit pkgs; };
  in
  {
    imports = [
      # 通过导出的结构引入模块 (包含 disko)
      dot-exts.hardware.disk-config.btrfs.nixosModule
    ];
 
    # 配置模块
    config.exts.hardware.disk = {
      enable = true;
      device = "/dev/sda"; # 建议使用 /dev/disk/by-id/...
      swapSize = 4096;
      imageBaseSize = 3072;
    };
  }
else
  # ---------------------------------------------------------
  # Mode 2: CLI Entrypoint (Called by disko CLI)
  # ---------------------------------------------------------
  {
    # 假设 ./host/default.nix 是您的系统构建入口 (调用了 lib.nixosSystem)
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

## 测试 (Testing)

该模块包含一套自动化测试套件，用于确保磁盘布局逻辑的准确性和配置的可构建性。

### 运行测试

在仓库根目录下，执行脚本运行完整测试套件：

```bash
./hardware/disk-config/btrfs/tests/run-tests.sh
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

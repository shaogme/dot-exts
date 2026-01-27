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
 
#### 选项 B: 传统方式 (Legacy)
 
在你的 NixOS 配置中（通过自动加载器或直接 import）：
 
```nix
{ pkgs, ... }:
let
  # 假设你已经获取了本仓库的源码路径
  myRepo = import ./path/to/repo { inherit pkgs; };
in
{
  imports = [
    # 导入 Btrfs 磁盘配置模块
    myRepo.hardware.disk-config.btrfs.nixosModule
  ];
 
  # ... 其他配置
}
```

### 2. 配置选项

通过 `exts.hardware.disk` 命名空间进行配置：

```nix
{ config, ... }:
{
  config.exts.hardware.disk = {
    # [必填] 启用磁盘配置模块
    enable = true;

    # [可选] 目标磁盘设备路径 (默认: "/dev/sda")
    # 对于 NVMe 硬盘通常是 "/dev/nvme0n1"
    device = "/dev/vda";

    # [可选] Swap 分区大小 (单位: MB)
    # 设置为 0 或 null 以禁用 Swap 分区 (默认: 0)
    swapSize = 4096; # 创建 4GB 的 Swap
  };
}
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

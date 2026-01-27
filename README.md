# Dot Exts

这是一个专为 NixOS 设计的模块化配置库，旨在提供开箱即用的高性能组件和硬件配置方案。本项目采用 Nix 语言编写，通过模块化的方式轻松集成到您的 NixOS 系统配置中。

## ✨ 特性 (Features)

*   **模块化设计**: 组件独立，按需引用，互不干扰。
*   **高性能内核**: 集成 CachyOS 内核，默认启用 BBRv3 和 CAKE 拥塞控制，显著提升网络与系统响应速度。
*   **标准化磁盘布局**: 提供基于 [disko](https://github.com/nix-community/disko) 的 Btrfs 最佳实践布局 (Subvolumes, Compression, etc.)。
*   **自动化测试**: 每个模块均包含完善的 VM 测试和静态检查，确保配置的稳定性和可构建性。
*   **依赖管理**: 使用 `npins` 进行精确的依赖版本锁定与管理，并配备自动更新工作流。

## 📦 模块列表 (Modules)

当前版本包含以下核心模块：

### 1. CachyOS 内核 (`kernel.cachyos`)
为 NixOS 提供 CachyOS 内核支持，集成高性能网络优化。
*   **自动集成**: 替换默认内核为 `linuxPackages-cachyos-latest`。
*   **网络优化**: 默认启用 BBRv3 TCP 拥塞控制与 CAKE 队列管理。
*   **详细文档**: [kernel/cachyos/README.md](./kernel/cachyos/README.md)

### 2. Btrfs 磁盘配置 (`hardware.disk-config.btrfs`)
提供开箱即用的 Btrfs 分区与子卷布局方案。
*   **标准布局**: 包含 ESP, Boot, Swap 及优化过的 Btrfs 子卷 (`@`, `@home`, `@nix`, `@log`)。
*   **透明压缩**: 默认启用 `zstd:3` 压缩以节省空间并提升 I/O 吞吐。
*   **详细文档**: [hardware/disk-config/btrfs/README.md](./hardware/disk-config/btrfs/README.md)

## 🚀 快速开始 (Getting Started)

### 选项 A: 使用 Flakes (推荐)

如果您使用 Nix Flakes 管理配置，可以将本库作为 inputs 引入。

**`flake.nix` 示例:**

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # 引入 dot-exts 库
    dot-exts.url = "github:shaogme/dot-exts";
  };

  outputs = { self, nixpkgs, dot-exts, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # 方法 1: 引入所有模块 (包含 CachyOS 内核和 Btrfs 磁盘配置)
        dot-exts.nixosModules.default

        # 方法 2: 仅引入特定模块
        # dot-exts.nixosModules.kernel-cachyos
        # dot-exts.nixosModules.disk-btrfs
        
        {
          # 启用并配置模块功能
          exts.hardware.disk.enable = true;
          exts.hardware.disk.device = "/dev/nvme0n1"; 
          
          exts.kernel.cachyos.enable = true;
        }
      ];
    };
  };
}
```

### 选项 B: 传统方式 (Legacy / Channels)

如果您不使用 Flakes，可以通过 fetchTarball 或 git submodule 获取源码并直接导入。

**`configuration.nix` 示例:**

```nix
{ pkgs, ... }:
let
  # 假设本仓库位于 ./modules 目录，或者通过 fetchTarball 拉取
  # myLib = import (builtins.fetchTarball "https://github.com/shaogme/dot-exts/archive/main.tar.gz") { inherit pkgs; };
  myLib = import ./modules { inherit pkgs; };
in
{
  imports = [
    # 引入 CachyOS 内核模块
    myLib.kernel.cachyos.nixosModule
    # 引入 Btrfs 磁盘配置模块
    myLib.hardware.disk-config.btrfs.nixosModule
  ];

  # 启用并配置模块功能
  exts.hardware.disk.enable = true;      # 启用磁盘配置
  exts.hardware.disk.device = "/dev/nvme0n1"; 

  exts.kernel.cachyos.enable = true;       # 启用 CachyOS 内核
}
```

## 🛠️ 开发与测试 (Development)

本项目通过 Docker 提供一致的开发环境，并使用脚本进行自动化测试。

*   **开发环境说明**: [README_DEV.md](./README_DEV.md)
*   **运行所有测试**:
    ```bash
    ./run-all-tests.sh
    ```
    该脚本会递归查找并执行仓库中所有的 `run-tests.sh` 脚本。

*   **依赖更新**:
    本项目使用 `npins` 管理依赖。
    ```bash
    ./update-npins.sh
    ```
    Github Actions 会每日自动检查并提交依赖更新的 Pull Request。

## 📄 许可证 (License)

本项目采用 [MIT License](./LICENSE) 开源。

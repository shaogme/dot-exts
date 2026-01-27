# CachyOS 内核模块 (CachyOS Kernel Module)

本模块位于 `kernel/cachyos`，旨在为 NixOS 提供 **CachyOS** 内核支持，并集成了 **BBRv3** 等高性能网络优化配置。

CachyOS 内核是针对性能进行优化的 Linux 内核分支，通常包含最新的调度器（如 EEVDF）、优化的构建选项以及 BBRv3 TCP 拥塞控制算法。

## 目录结构 (Directory Structure)

```
kernel/cachyos/
├── default.nix          # 模块入口，导出 Overlay 和 NixOS Module
├── sysctl.nix           # BBRv3 及高带宽网络优化的 Sysctl 参数
├── npins/               # 依赖源锁定 (包含 nix-cachyos-kernel)
└── tests/               # 自动化测试套件
    ├── default.nix      # 测试聚合入口
    ├── build.nix        # 内核包构建测试
    ├── static.nix       # 静态配置检查
    ├── vmtest.nix       # 虚拟机运行时测试
    └── run-tests.sh     # 测试运行脚本
```

## 功能特性 (Features)

1.  **CachyOS Kernel**: 自动集成并使用最新的 CachyOS 内核包（通过 Overlay）。
2.  **BBRv3 拥塞控制**: 默认启用 BBRv3 (`tcp_bbr` 模块)，显著提升弱网和高带宽环境下的网络吞吐量。
3.  **CAKE Qdisc**: 默认配置 CAKE 队列管理算法，有效对抗 Bufferbloat。
4.  **网络栈调优**: 针对现代千兆/万兆网络环境，优化了 TCP 缓冲区、连接追踪表及 Keepalive 参数。
5.  **Binary Cache**: 自动配置 CachyOS 相关的 Binary Cache，加速内核下载。

## 使用说明 (Usage)

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
        dot-exts.nixosModules.kernel-cachyos
 
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
  myRepo = import ./path/to/repo { inherit pkgs; };
in
{
  imports = [
    # 导入 CachyOS 内核模块
    myRepo.kernel.cachyos.nixosModule
  ];
}
```

### 2. 启用配置

通过 `exts.kernel.cachyos` 命名空间启用功能：

```nix
{ config, ... }:
{
  # 启用 CachyOS 内核及网络优化
  config.exts.kernel.cachyos.enable = true;
}
```

启用后，系统将会：
*   替换默认内核为 `linuxPackages-cachyos-latest`。
*   应用 `sysctl.nix` 中的网络优化参数。
*   加载 `tcp_bbr` 模块。

## 网络优化详解 (Network Optimization)

该模块在 `sysctl.nix` 中定义了一系列高性能网络参数，主要包括：

*   **拥塞控制**: `net.ipv4.tcp_congestion_control = "bbr"` (BBRv3)
*   **队列管理**: `net.core.default_qdisc = "cake"`
*   **缓冲区扩大**: 增大 `rmem_max` / `wmem_max` 至 16MB+，适应高带宽。
*   **低延迟**: 开启 TCP Fast Open (`3`)，禁用空闲慢启动 (`tcp_slow_start_after_idle = 0`)。
*   **高并发**: 增加 SYN 半连接队列 (`8192`) 和全连接队列 (`8192`) 上限。

## 测试 (Testing)

本模块包含完善的测试套件，位于 `tests/` 目录下，确保配置的正确性和稳定性。

### 运行测试

在仓库根目录下，执行以下脚本即可运行完整测试：

```bash
./kernel/cachyos/tests/run-tests.sh
```

该脚本会自动处理依赖，并顺序执行静态检查和 VM 测试。由于测试涉及虚拟机启动，建议在支持 KVM 的机器上运行。

### 测试项细则

测试套件由 `tests/default.nix` 聚合，包含三个主要部分：

1.  **静态配置检查 (`static.nix`)**
    *   **目标**: 快速验证 NixOS 配置生成逻辑。
    *   **内容**: 
        *   检查 `boot.kernelPackages` 名称是否包含 "cachyos"。
        *   验证 `sysctl` 参数（如 BBR、CAKE）是否正确写入配置。
        *   确认 `tcp_bbr` 模块是否被加入加载列表。
    *   **特点**: 速度快，无需编译内核。

2.  **虚拟机运行时测试 (`vmtest.nix`)**
    *   **目标**: 验证系统真实启动后的状态。
    *   **内容**: 
        *   构建一个微型 NixOS 虚拟机。
        *   启动并等待系统就绪。
        *   运行 `uname -r` 确认运行的是 CachyOS 内核。
        *   通过 `sysctl` 命令查询运行时内核参数，验证 BBRv3 和 CAKE 生效。
        *   检查 `lsmod` 确认模块加载。

3.  **构建测试 (`build.nix`)**
    *   **目标**: 验证内核包本身及其依赖能否成功构建。
    *   **内容**: 尝试实例化内核包的 DRV (Derivation)。

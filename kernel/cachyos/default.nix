{ pkgs, ... }:
let
  sources = import ./npins;
  
  cachyosFlake = import sources.nix-cachyos-kernel;
in
{
  # 1. 暴露 overlay (供上层 configuration.nix 使用，以提供 CachyOS 内核包)
  # 使用 'pinned' overlay 避免上游警告
  overlay = cachyosFlake.outputs.overlays.pinned;

  # 2. 暴露 NixOS Module (供上层 configuration.nix import 使用)
  # 根据 interface.nix 要求，返回一个 module 定义
  nixosModule = { config, lib, pkgs, ... }:
    let
      cfg = config.exts.kernel.cachyos;
      sysctlConfig = import ./sysctl.nix;
    in {
      options.exts.kernel.cachyos = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable CachyOS kernel with BBRv3 network optimization";
        };
      };

      config = lib.mkIf cfg.enable {
        # 必须应用 overlay 才能在 pkgs 中找到 cachyosKernels
        nixpkgs.overlays = [ cachyosFlake.outputs.overlays.pinned ];

        # 使用最新版 CachyOS 内核
        boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

        # 确保加载 BBR 模块 (对于 CachyOS 内核，tcp_bbr 即为 BBRv3)
        boot.kernelModules = [ "tcp_bbr" ];

        # 网络栈参数调优 (从 sysctl.nix 导入)
        boot.kernel.sysctl = sysctlConfig;
        
        # scx_rustland 旨在将交互式工作负载优先于后台CPU密集型工作负载
        # 这里默认关闭，因为可能需要额外的 scx 包支持
        services.scx.enable = lib.mkDefault false;

        # 添加 CachyOS 的 binary cache 配置
        nix.settings = {
          substituters = [
            "https://attic.xuyh0120.win/lantian"
            "https://cache.garnix.io"
          ];
          trusted-public-keys = [
            "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
            "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
          ];
        };
      };
    };
}

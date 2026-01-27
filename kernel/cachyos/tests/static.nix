{ pkgs ? import <nixpkgs> { } }:

let
  repo = import ../../../default.nix { inherit pkgs; };

  # Use NixOS's testing framework
  evalConfig = import (pkgs.path + "/nixos/lib/eval-config.nix");

  # Define a minimal NixOS system that uses our module
  testResult = evalConfig {
    modules = [
      repo.kernel.cachyos.nixosModule
      {
        # Basic NixOS configuration
        boot.loader.grub.enable = false;
        boot.loader.systemd-boot.enable = true;
        fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
        
        # Enable our module
        exts.kernel.cachyos.enable = true;
        
        # Mocking necessary system settings
        system.stateVersion = "23.11";
      }
    ];
    inherit pkgs;
    system = "x86_64-linux";
  };
  
  config = testResult.config;

in
pkgs.runCommand "test-kernel-cachyos" { } ''
  # 1. Check if kernel package is set correctly to cachyos
  # Note: The actual package name might vary, we check if it contains "cachyos" in the name or description
  if [[ "${config.boot.kernelPackages.kernel.name}" == *"cachyos"* ]]; then
    echo "PASS: Kernel package name contains cachyos: ${config.boot.kernelPackages.kernel.name}"
  else
    echo "FAIL: Kernel package does not seem to be CachyOS. Got: ${config.boot.kernelPackages.kernel.name}"
    exit 1
  fi

  # 2. Check if sysctl parameters are applied
  # We check a specific unique BBRv3 setting, e.g., net.ipv4.tcp_congestion_control = "bbr"
  if [[ "${config.boot.kernel.sysctl."net.ipv4.tcp_congestion_control"}" == "bbr" ]]; then
    echo "PASS: TCP congestion control is set to bbr"
  else
    echo "FAIL: TCP congestion control is NOT bbr. Got: ${config.boot.kernel.sysctl."net.ipv4.tcp_congestion_control"}"
    exit 1
  fi
  
   # 3. Check if kernel modules include tcp_bbr
  if [[ "${toString config.boot.kernelModules}" == *"tcp_bbr"* ]]; then
    echo "PASS: Kernel modules include tcp_bbr"
  else
    echo "FAIL: Kernel modules missing tcp_bbr. Got: ${toString config.boot.kernelModules}"
    exit 1
  fi

  # 4. Check if CAKE qdisc is enabled
  if [[ "${config.boot.kernel.sysctl."net.core.default_qdisc"}" == "cake" ]]; then
    echo "PASS: Default qdisc is cake"
  else
    echo "FAIL: Default qdisc is NOT cake. Got: ${config.boot.kernel.sysctl."net.core.default_qdisc"}"
    exit 1
  fi

  mkdir $out
  echo "All tests passed" > $out/success
''

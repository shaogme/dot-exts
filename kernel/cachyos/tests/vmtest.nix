{ pkgs ? import <nixpkgs> { } }:

let
  cachyosDir = import ../default.nix { inherit pkgs; };
  cachyosModule = cachyosDir.nixosModule;

in
pkgs.testers.nixosTest {
  name = "cachyos-kernel-boot-vmtest";

  nodes.machine = { config, pkgs, ... }: {
    imports = [ 
      cachyosModule 
    ];

    # Enable CachyOS module
    exts.kernel.cachyos.enable = true;

    # VM specific settings
    virtualisation.writableStore = true;
    virtualisation.memorySize = 2048; 
    
    # Basic boot configuration
    boot.loader.systemd-boot.enable = true;
    fileSystems."/" = { device = "/dev/vda1"; fsType = "ext4"; };
    
    system.stateVersion = "23.11";
  };

  testScript = ''
    start_all()
    
    # Wait for the system to boot
    machine.wait_for_unit("multi-user.target")
    
    # 1. Check running kernel
    uname_r = machine.succeed("uname -r").strip()
    print(f"Running Kernel: {uname_r}")
    if "cachyos" not in uname_r:
        raise Exception(f"Kernel version '{uname_r}' does not contain 'cachyos'!")

    # 2. Check Sysctl BBR
    cc = machine.succeed("sysctl -n net.ipv4.tcp_congestion_control").strip()
    if cc != "bbr":
        raise Exception(f"TCP congestion control is '{cc}', expected 'bbr'")

    # 3. Check Qdisc CAKE
    qdisc = machine.succeed("sysctl -n net.core.default_qdisc").strip()
    if qdisc != "cake":
        raise Exception(f"Default qdisc is '{qdisc}', expected 'cake'")

    # 4. Check kernel module
    lsmod = machine.succeed("lsmod")
    if "tcp_bbr" not in lsmod:
        raise Exception("Module 'tcp_bbr' is not loaded!")
        
    print("All CachyOS runtime tests passed!")
  '';
}

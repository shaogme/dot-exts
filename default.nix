{ pkgs }:
let
  lib = pkgs.lib;
  # Function to inject pkgs into subdirectory modules
  callExt = path: import path { inherit pkgs; };
  
  btrfs = callExt ./hardware/disk/btrfs;
  cachyos = callExt ./kernel/cachyos;
in
{
  nixosModules = {
    hardware.disk.btrfs = btrfs.nixosModule;
    kernel.cachyos = cachyos.nixosModule;
    
    default = { ... }: {
      imports = [ ];
    };
  };

  # Individual component access
  hardware.disk.btrfs = btrfs;
  kernel.cachyos = cachyos;
}

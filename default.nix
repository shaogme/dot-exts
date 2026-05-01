{ pkgs }:
let
  lib = pkgs.lib;
  # Function to inject pkgs into subdirectory modules
  callExt = path: import path { inherit pkgs; };
  
  btrfs = callExt ./hardware/disk/btrfs;
  cachyos = callExt ./kernel/cachyos;

  # Base module with global options
  baseModule = ./core/options.nix;

  # Helper to wrap a module with base dependencies
  wrapModule = m: {
    imports = [ baseModule m ];
  };
in
{
  nixosModules = {
    hardware.disk.btrfs = wrapModule btrfs.nixosModule;
    kernel.cachyos = wrapModule cachyos.nixosModule;
    testMode = baseModule;
    
    default = { ... }: {
      imports = [ baseModule ];
    };
  };

  # Individual component access
  hardware.disk.btrfs = btrfs;
  kernel.cachyos = cachyos;
}

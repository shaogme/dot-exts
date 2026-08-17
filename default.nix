{ pkgs ? null, lib ? null, ... } @ args:
let
  resolvedLib =
    if lib != null then lib
    else if pkgs != null && pkgs ? lib then pkgs.lib
    else (import <nixpkgs> { }).lib;

  callExt = path: import path (if pkgs != null then { inherit pkgs; } else { });
  
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

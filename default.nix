{ pkgs ? null, lib ? null, ... } @ args:
let
  sources = import ./npins;
  resolvedPkgs =
    if pkgs != null then pkgs
    else import (sources.nixpkgs { }) { };
  resolvedLib =
    if lib != null then lib
    else resolvedPkgs.lib;

  callExt = path: import path { pkgs = resolvedPkgs; };
  
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

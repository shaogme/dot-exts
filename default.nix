{ pkgs ? {} }:
let
  lib = pkgs.lib;
  # Function to inject pkgs into subdirectory modules
  callExt = path: import path { inherit pkgs; };
in
{
  hardware = {
    disk-config = {
      btrfs = callExt ./hardware/disk-config/btrfs;
    };
  };
  kernel = {
    cachyos = callExt ./kernel/cachyos;
  };
}

{ pkgs }:
let
  lib = pkgs.lib;
  # Function to inject pkgs into subdirectory modules
  callExt = path: import path { inherit pkgs; };
in
{
  hardware = {
    disk = {
      btrfs = callExt ./hardware/disk/btrfs;
    };
  };
  kernel = {
    cachyos = callExt ./kernel/cachyos;
  };
}

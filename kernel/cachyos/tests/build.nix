{ pkgs ? import <nixpkgs> { } }:

let
  cachyosDir = import ../default.nix { inherit pkgs; };
  
  # Construct pkgs with CachyOS overlay
  pkgsWithKernel = import pkgs.path {
    inherit (pkgs) system;
    overlays = [ cachyosDir.overlay ];
  };
in
  # Return the kernel package derivation to trigger build
  pkgsWithKernel.cachyosKernels.linuxPackages-cachyos-latest.kernel

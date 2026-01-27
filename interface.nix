
# Interface Contract for this repository
#
# Each subdirectory (module) should expose a function with the following signature:
#
# { pkgs, ... }:
# {
#   # The function must return a set containing one of the following keys:
#
#   # 1. nixosModule: A NixOS module (function or attribute set)
#   #    e.g. { config, lib, ... }: { options = ...; config = ...; }
#   nixosModule = { ... };
#
#   # 2. overlay: A Nixpkgs overlay function
#   #    e.g. final: prev: { ... }
#   # overlay = ...;
# }
{ }

{ pkgs ? import <nixpkgs> { } }:

let
  staticCheck = import ./static.nix { inherit pkgs; };
  vmTest = import ./vmtest.nix { inherit pkgs; };
  buildTest = import ./build.nix { inherit pkgs; };
in
{
  inherit staticCheck vmTest buildTest;
}

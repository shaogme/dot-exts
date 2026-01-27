{
  description = "Dot Exts";

  inputs = {
    # No external inputs required for modules
  };

  outputs = { self, ... }:
  let
    # Load the library using the local default.nix.
    # We pass an empty set for pkgs because we only need the module structure (attributes).
    # The actual NixOS modules handle pkgs injection internally.
    myLib = import ./default.nix { };
  in
  {
    nixosModules = {
      # 1. CachyOS Kernel Module
      kernel-cachyos = myLib.kernel.cachyos.nixosModule;

      # 2. Btrfs Disk Config Module
      disk-btrfs = myLib.hardware.disk-config.btrfs.nixosModule;

      # 3. Default (All-in-one)
      default = { ... }: {
        imports = [
          self.nixosModules.kernel-cachyos
          self.nixosModules.disk-btrfs
        ];
      };
    };

    # --- Overlays ---
    overlays.default = final: prev:
      # Extract overlay directly from the module instantiation
      (import ./kernel/cachyos { pkgs = prev; }).overlay final prev;
  };
}

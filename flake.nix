{
  description = "Dot Exts";

  inputs = {
    # No external inputs required for modules
  };

  outputs = { self, ... }:
  let
    # Manually configure the module structure
    kernel-cachyos = (import ./kernel/cachyos { pkgs = { }; }).nixosModule;
    disk-btrfs = (import ./hardware/disk/btrfs { pkgs = { }; }).nixosModule;
  in
  {
    nixosModules = {
      # 1. Structured organization
      kernel.cachyos = kernel-cachyos;
      hardware.disk.btrfs = disk-btrfs;

      # 2. Flat access (for convenience and backward compatibility)
      inherit kernel-cachyos disk-btrfs;

      # 3. Default (All-in-one)
      default = { ... }: {
        imports = [
          kernel-cachyos
          disk-btrfs
        ];
      };
    };

    # --- Overlays ---
    overlays.default = final: prev:
      # Extract overlay directly from the module instantiation
      (import ./kernel/cachyos { pkgs = prev; }).overlay final prev;
  };
}

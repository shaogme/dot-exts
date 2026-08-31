{
  description = "Integration Test for Dot-Exts Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # Reference the local project root
    dot-exts.url = "path:../../";
  };

  outputs = { self, nixpkgs, dot-exts, ... }: {
    nixosConfigurations.testMachine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the library via Flake
        dot-exts.nixosModules.kernel.cachyos
        dot-exts.nixosModules.hardware.disk.btrfs
        
        {
          # --- Disk Config Requirements ---
          exts.hardware.disk.btrfs = {
            enable = true;
            imageBaseSize = 2048;
            partitions.root = {
              size = "100%";
              subvolumes = {
                "@" = { mountpoint = "/"; };
                "@home" = { mountpoint = "/home"; };
                "@nix" = { mountpoint = "/nix"; };
                "@log" = { mountpoint = "/var/log"; neededForBoot = true; };
              };
            };
          };
          
          # --- CachyOS Config ---
          exts.kernel.cachyos.enable = true;

          # --- Minimal System Requirements ---
          boot.loader.grub.device = "nodev";
          system.stateVersion = "24.05";
        }
      ];
    };
  };
}

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
        dot-exts.nixosModules.default
        
        {
          # --- Disk Config Requirements ---
          exts.hardware.disk.enable = true;
          # 'imageBaseSize' has no default, must be set
          exts.hardware.disk.imageBaseSize = 2048;
          
          # --- CachyOS Config (Optional, enabled by default) ---
          exts.kernel.cachyos.enable = true;

          # --- Minimal System Requirements ---
          boot.loader.grub.device = "nodev";
          system.stateVersion = "24.05";
        }
      ];
    };
  };
}

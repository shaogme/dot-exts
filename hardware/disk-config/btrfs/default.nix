{ pkgs, ... }:
let
  sources = import ../npins;
in
{
  nixosModule = { lib, config, pkgs, ... }: {
    imports = [ "${sources.disko}/module.nix" ];

    options.exts.hardware.disk = {
      enable = lib.mkEnableOption "Disk Configuration";
      
      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/sda";
        description = "The disk device to use (e.g. /dev/sda)";
      };
      
      swapSize = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = 0;
        description = "Swap size in MB. Set to 0 or null to disable swap.";
      };

      imageBaseSize = lib.mkOption {
        type = lib.types.int;
        description = "Base size of the disk image in MB (excluding swap). This must be explicitly set.";
      };
    };

    config = lib.mkIf config.exts.hardware.disk.enable (let
      cfg = config.exts.hardware.disk;
      # Handle swapSize being null, treating it as 0
      safeSwapSize = if cfg.swapSize != null then cfg.swapSize else 0;
      imageSize = "${toString (safeSwapSize + cfg.imageBaseSize)}M";

      # Btrfs and subvolume definition for reuse
      btrfsContent = {
        type = "btrfs";
        extraArgs = [ "-f" ];
        subvolumes = {
          "@" = {
            mountpoint = "/";
            mountOptions = [ "compress-force=zstd:3" "noatime" "space_cache=v2" ];
          };
          "@home" = {
            mountpoint = "/home";
            mountOptions = [ "compress-force=zstd:3" "noatime" "space_cache=v2" ];
          };
          "@nix" = {
            mountpoint = "/nix";
            mountOptions = [ "compress-force=zstd:3" "noatime" "space_cache=v2" ];
          };
          "@log" = {
            mountpoint = "/var/log";
            mountOptions = [ "compress-force=zstd:3" "noatime" "space_cache=v2" ];
          };
        };
      };
    in {
      # --- Bootloader Configuration ---
      # Disable systemd-boot
      boot.loader.systemd-boot.enable = false;
      
      # Specify EFI mount point (must match Disko config)
      boot.loader.efi.efiSysMountPoint = "/boot/efi";

      # GRUB Configuration
      boot.loader.grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        
        # Install boot files to default location to prevent motherboard "amnesia"
        efiInstallAsRemovable = true;
      };
      
      boot.supportedFilesystems = [ "btrfs" ];

      # --- Disk Configuration ---
      disko.devices.disk.main = {
        # Specify generated raw file initial size
        inherit imageSize;

        device = cfg.device;
        content = {
          type = "gpt";
          # Use // operator and lib.optionalAttrs to dynamically build partition set
          partitions = {
            # For BIOS+GPT boot
            boot = {
              priority = 0;
              size = "1M";
              type = "EF02"; 
            };
            # 1. ESP Partition
            ESP = {
              priority = 1;
              size = "32M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
                mountOptions = [ "defaults" ];
              };
            };
          } 
          # Add Swap partition only if safeSwapSize > 0
          // lib.optionalAttrs (safeSwapSize > 0) {
            swap = {
              priority = 3;
              size = "${toString safeSwapSize}M";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true;
              };
            };
          } 
          # Continue adding remaining Root partition
          // {
            # 3. Root Partition
            root = {
              priority = 4;
              size = "100%";
              content = btrfsContent;
            };
          };
        };
      };

      fileSystems."/var/log".neededForBoot = true;

      # Automatically fix GPT partition table and expand last partition on boot
      boot.growPartition = true;

      # Auto resize for Btrfs root partition
      fileSystems."/".autoResize = true;

      # Ensure necessary tools are in system path (cloud-utils includes growpart)
      environment.systemPackages = [ pkgs.cloud-utils ];
    });
  };
}

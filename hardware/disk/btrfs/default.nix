{ pkgs ? null, ... }:
let
  sources = import ../npins;
in
{
  nixosModule = { lib, config, pkgs, ... }: {
    imports = [ 
      "${sources.disko}/module.nix" 
    ];

    options.exts.hardware.disk.btrfs = {
      enable = lib.mkEnableOption "Declarative Btrfs Disk & Partition Configuration";
      
      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/sda";
        description = "The disk device to partition (e.g. /dev/sda, /dev/vda, /dev/disk/by-id/...).";
      };
      
      swapSize = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = 0;
        description = "Swap size in MB. Set to 0 or null to disable swap.";
      };

      imageBaseSize = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Base size of the disk image in MB (excluding swap), used for disko image creation.";
      };

      imageSize = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Total size of the generated disk image (e.g. '10G', '7168M'). Overrides imageBaseSize + swapSize.";
      };

      biosBoot = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to create BIOS boot partition (EF02).";
        };
        size = lib.mkOption {
          type = lib.types.str;
          default = "1M";
          description = "Size of BIOS boot partition.";
        };
      };

      esp = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to create ESP partition (EF00).";
        };
        size = lib.mkOption {
          type = lib.types.str;
          default = "32M";
          description = "Size of ESP partition.";
        };
        mountpoint = lib.mkOption {
          type = lib.types.str;
          default = "/boot/efi";
          description = "Mount point for ESP partition.";
        };
      };

      defaultMountOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "compress-force=zstd:3" "noatime" "space_cache=v2" ];
        description = "Default mount options for Btrfs volumes and subvolumes.";
      };

      partitions = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            size = lib.mkOption {
              type = lib.types.str;
              default = "100%";
              description = "Size of this GPT partition (e.g. '10G', '2048M', '100%').";
            };

            priority = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Partition order priority in Disko.";
            };

            mountpoint = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Direct mount point for the Btrfs partition (maps to default subvolume '@').";
            };

            mountOptions = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              description = "Mount options for this partition. If null, uses defaultMountOptions.";
            };

            neededForBoot = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Whether this mount is needed during early boot.";
            };

            autoResize = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Whether to enable auto-resize for this filesystem.";
            };

            extraArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "-f" ];
              description = "Extra arguments passed to mkfs.btrfs.";
            };

            subvolumes = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  mountpoint = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Mount point for this subvolume.";
                  };
                  mountOptions = lib.mkOption {
                    type = lib.types.nullOr (lib.types.listOf lib.types.str);
                    default = null;
                    description = "Mount options for this subvolume. If null, inherits from partition.";
                  };
                  neededForBoot = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Whether this subvolume is needed during early boot.";
                  };
                  autoResize = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Whether to auto-resize this filesystem.";
                  };
                };
              });
              default = {};
              description = "Subvolumes defined within this Btrfs partition.";
            };
          };
        });
        default = {};
        description = "Declarative definition of Btrfs partitions.";
      };
    };

    config = lib.mkIf config.exts.hardware.disk.btrfs.enable (let
      cfg = config.exts.hardware.disk.btrfs;
      safeSwapSize = if cfg.swapSize != null then cfg.swapSize else 0;
      calculatedImageSize =
        if cfg.imageSize != null then cfg.imageSize
        else if cfg.imageBaseSize != null then "${toString (safeSwapSize + cfg.imageBaseSize)}M"
        else null;

      resolveMountOptions = partOpts: subvolOpts:
        if subvolOpts != null then subvolOpts
        else if partOpts != null then partOpts
        else cfg.defaultMountOptions;

      resolveNeededForBoot = partNeeded: subvolNeeded: mountpoint: subvolName:
        if subvolNeeded != null then subvolNeeded
        else if partNeeded != null then partNeeded
        else (mountpoint == "/" || mountpoint == "/var/log" || subvolName == "@log");

      resolveAutoResize = partResize: subvolResize: mountpoint: subvolName:
        if subvolResize != null then subvolResize
        else if partResize != null then partResize
        else (mountpoint == "/" || subvolName == "@");

      userPartitions = lib.mapAttrs (name: partCfg:
        let
          partMountOpts = resolveMountOptions partCfg.mountOptions null;
          directSubvol = lib.optionalAttrs (partCfg.mountpoint != null) {
            "@" = {
              mountpoint = partCfg.mountpoint;
              mountOptions = partMountOpts;
            };
          };
          explicitSubvols = lib.mapAttrs (subvolName: subvolCfg: {
            inherit (subvolCfg) mountpoint;
            mountOptions = resolveMountOptions partCfg.mountOptions subvolCfg.mountOptions;
          }) partCfg.subvolumes;
        in {
          size = partCfg.size;
          content = {
            type = "btrfs";
            extraArgs = partCfg.extraArgs;
            subvolumes = directSubvol // explicitSubvols;
          };
        } // (lib.optionalAttrs (partCfg.priority != null) { priority = partCfg.priority; })
      ) cfg.partitions;

      diskoPartitions =
        (lib.optionalAttrs cfg.biosBoot.enable {
          boot = {
            priority = 0;
            size = cfg.biosBoot.size;
            type = "EF02";
          };
        })
        // (lib.optionalAttrs cfg.esp.enable {
          ESP = {
            priority = 1;
            size = cfg.esp.size;
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = cfg.esp.mountpoint;
              mountOptions = [ "defaults" ];
            };
          };
        })
        // (lib.optionalAttrs (safeSwapSize > 0) {
          swap = {
            priority = 3;
            size = "${toString safeSwapSize}M";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true;
            };
          };
        })
        // userPartitions;
    in lib.mkMerge [
      {
        boot.supportedFilesystems = [ "btrfs" ];
        environment.systemPackages = [ pkgs.cloud-utils ];
        assertions = [
          {
            assertion = cfg.partitions != {};
            message = "exts.hardware.disk.btrfs: At least one partition must be defined in 'exts.hardware.disk.btrfs.partitions'.";
          }
        ];
      }
      (lib.mkIf (! (config.exts.testMode or false)) {
        # --- Bootloader Configuration ---
        boot.loader.systemd-boot.enable = false;
        boot.loader.efi.efiSysMountPoint = cfg.esp.mountpoint;
        boot.loader.grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };

        # --- Disk Configuration ---
        disko.devices.disk.main = {
          device = cfg.device;
          content = {
            type = "gpt";
            partitions = diskoPartitions;
          };
        } // (lib.optionalAttrs (calculatedImageSize != null) {
          imageSize = calculatedImageSize;
        });

        fileSystems."/var/log".neededForBoot = lib.mkDefault true;
        fileSystems."/".autoResize = lib.mkDefault true;

        # Automatically fix GPT partition table and expand last partition on boot
        boot.growPartition = true;
      })
    ]);
  };
}

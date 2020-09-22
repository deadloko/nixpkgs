# This module creates a bootable SD card image containing the given NixOS
# configuration. The generated image is MBR partitioned, with a FAT
# /boot/firmware partition, and ext4 root partition. The generated image
# is sized to fit its contents, and a boot script automatically resizes
# the root partition to fit the device on the first boot.
#
# The firmware partition is built with expectation to hold the Raspberry
# Pi firmware and bootloader, and be removed and replaced with a firmware
# build for the target SoC for other board families.
#
# The derivation for the SD image will be placed in
# config.system.build.teziTarballs

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    (mkRemovedOptionModule [ "sdImage" "bootPartitionID" ] "The FAT partition for SD image now only holds the Raspberry Pi firmware files. Use firmwarePartitionID to configure that partition's ID.")
    (mkRemovedOptionModule [ "sdImage" "bootSize" ] "The boot files for SD image have been moved to the main ext4 partition. The FAT partition now only holds the Raspberry Pi firmware files. Changing its size may not be required.")
  ];

  options.sdImage = {
    imageName = mkOption {
      default = "${config.sdImage.imageBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.img";
      description = ''
        Name of the generated image file.
      '';
    };

    imageBaseName = mkOption {
      default = "nixos-sd-image";
      description = ''
        Prefix of the name of the generated image file.
      '';
    };

    storePaths = mkOption {
      type = with types; listOf package;
      example = literalExample "[ pkgs.stdenv ]";
      description = ''
        Derivations to be included in the Nix store in the generated SD image.
      '';
    };

    firmwarePartitionID = mkOption {
      type = types.str;
      default = "0x2178694e";
      description = ''
        Volume ID for the /boot/firmware partition on the SD card. This value
        must be a 32-bit hexadecimal number.
      '';
    };

    rootPartitionUUID = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "14e19a7b-0ae0-484d-9d54-43bd6fdc20c7";
      description = ''
        UUID for the main NixOS partition on the SD card.
      '';
    };

    firmwareSize = mkOption {
      type = types.int;
      # As of 2019-08-18 the Raspberry pi firmware + u-boot takes ~18MiB
      default = 30;
      description = ''
        Size of the /boot/firmware partition, in megabytes.
      '';
    };

    populateFirmwareCommands = mkOption {
      example = literalExample "'' cp \${pkgs.myBootLoader}/u-boot.bin firmware/ ''";
      description = ''
        Shell commands to populate the ./firmware directory.
        All files in that directory are copied to the
        /boot/firmware partition on the SD image.
      '';
    };

    populateRootCommands = mkOption {
      example = literalExample "''\${extlinux-conf-builder} -t 3 -c \${config.system.build.toplevel} -d ./files/boot''";
      description = ''
        Shell commands to populate the ./files directory.
        All files in that directory are copied to the
        root (/) partition on the SD image. Use this to
        populate the ./files/boot (/boot) directory.
      '';
    };

    postImageBuildCommands = mkOption {
      example = literalExample "'' cp boot $out ''";
      description = ''
        Commands to execute after image created.
        '';
    };

    compressImage = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the SD image should be compressed using
        <command>bzip2</command>.
      '';
    };

  };

  options.teziTarballs = {
    populateBootCommands = mkOption {
      example = literalExample " '' cp zImage ./boot/ '' ";
      description = ''
        Commands to populate boot folder that will be compressed into
        out/tezi-image/tezi-bootfs.tar.xz. For tezi images this tarball
        need to contain kernel image and devicetreefile.
        '';
    };
  };

  config = {
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/nixos_root";
        fsType = "ext4";
      };

      "/boot" = {
        device = "/dev/disk/by-label/nixos_boot";
        fsType = "vfat";
        options = [ "nofail" "noauto" ];
      };
    };

    sdImage.storePaths = [ config.system.build.toplevel ];

    system.build.teziTarballs = pkgs.callPackage ({ stdenv, dosfstools, e2fsprogs,
    mtools, libfaketime, utillinux, bzip2, zstd, lkl, lzma }: stdenv.mkDerivation {
      name = config.sdImage.imageName;

      nativeBuildInputs = [ dosfstools e2fsprogs mtools libfaketime utillinux bzip2 zstd lkl lzma ];

      inherit (config.sdImage) compressImage;

      buildCommand = let
        inherit (config.sdImage) storePaths;
        sdClosureInfo = pkgs.buildPackages.closureInfo { rootPaths = storePaths; };
      in
        ''
        mkdir -p $out/nix-support $out/tezi-image
        echo "${pkgs.stdenv.buildPlatform.system}" > $out/nix-support/system

        mkdir -p ./temp_root_fs
        ${config.sdImage.populateRootCommands}

        # Add the closures of the top-level store objects.
        storePaths=$(cat ${sdClosureInfo}/store-paths)

        cd temp_root_fs
        cp ${sdClosureInfo}/registration ./nix-path-registration
        mkdir -p nix/store
        cp -r $storePaths nix/store/

        time tar -Jcf $out/tezi-image/tezi-rootfs.tar.xz --sort=name --mtime='1970-01-01' --owner=0 --group=0 --numeric-owner -c *

        mkdir boot
        ${config.teziTarballs.populateBootCommands}
        cd boot
        time tar -Jcf $out/tezi-image/tezi-bootfs.tar.xz --sort=name --mtime='1970-01-01' --owner=0 --group=0 --numeric-owner -c *

        ${config.sdImage.postImageBuildCommands}
      '';
    }) {};

    boot.postBootCommands = ''
      # On the first boot do some maintenance tasks
      if [ -f /nix-path-registration ]; then
        set -euo pipefail
        set -x
        # Register the contents of the initial Nix store
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration
      fi
    '';
  };
}

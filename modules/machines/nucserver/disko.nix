# Disk layout, applied by nixos-anywhere on install (wipes the disk!).
# GRUB is installed both ways: as the removable EFI loader on the ESP (how the
# box boots) and in the 1M EF02 partition for legacy BIOS boot (disko adds the
# disk to boot.loader.grub.devices), so it boots whatever the firmware is set to.
# The LUKS passphrase comes from nixos-anywhere --disk-encryption-keys and never
# reaches the store; unattended unlock is enrolled in the TPM after first boot.
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02";
        };
        esp = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = "/tmp/secret.key";
            settings = {
              allowDiscards = true;
              crypttabExtraOpts = [ "tpm2-device=auto" ];
            };
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    # /boot is the ESP holding a kernel + initrd per generation.
    configurationLimit = 10;
  };
  boot.loader.efi.efiSysMountPoint = "/boot";
}

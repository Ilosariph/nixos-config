# Disk layout, applied by nixos-anywhere on install (wipes the disk!).
# Boots either way: the current VPS is BIOS (GRUB in the 1M EF02
# partition, disko adds the disk to boot.loader.grub.devices), newer instances
# may be UEFI (GRUB as the removable EFI loader on the ESP, no NVRAM writes).
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
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
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    # /boot is the 1G ESP holding a kernel + initrd per generation.
    configurationLimit = 10;
  };
  boot.loader.efi.efiSysMountPoint = "/boot";
}

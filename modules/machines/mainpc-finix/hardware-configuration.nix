# finix variant of ../mainpc/hardware-configuration.nix. finix has no
# modulesPath/not-detected.nix or networking.useDHCP (NetworkManager handles
# DHCP), so only kernel modules and filesystems carry over.
{ pkgs, ... }:
{
  boot.initrd.availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "thunderbolt" "usbhid" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # finix docs recommend a separate root partition instead of converting the
  # NixOS root in place. Create it with `mkfs.ext4 -L finix /dev/<partition>`.
  # The ESP is shared with NixOS: limine installs next to systemd-boot and
  # chainloads it (see bootloader aspect).
  fileSystems."/" = {
    device = "/dev/disk/by-label/finix";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/403E-F30E";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  hardware.firmware = [ pkgs.linux-firmware ];
  hardware.cpu.intel.updateMicrocode = true;
}

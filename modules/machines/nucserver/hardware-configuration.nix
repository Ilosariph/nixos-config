# Intel NUC, NVMe system disk. Filesystems come from disko.nix.
{ config, lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # usbhid/hid_generic: keyboard for the LUKS prompt. tpm_*: unlock from the TPM.
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "hid_generic" "usb_storage" "sd_mod" "tpm_crb" "tpm_tis" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

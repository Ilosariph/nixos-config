{ ... }:
{
  dotfiles.bootloader = "grub";
  dotfiles.grubDevice = "/dev/nvme0n1";
  dotfiles.use1PasswordAgent = false;
}

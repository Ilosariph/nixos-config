{ ... }: {
  flake.nixosModules.bootloader = { config, pkgs, lib, ... }: {
    config = lib.mkMerge [
      (lib.mkIf (config.dotfiles.bootloader.type == "systemd") {
        boot.loader.systemd-boot.enable = true;
        boot.loader.systemd-boot.consoleMode =
          if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "max" else "0";
        boot.loader.efi.canTouchEfiVariables = true;
      })
      (lib.mkIf (config.dotfiles.bootloader.type == "grub") {
        boot.loader.grub.enable = true;
        boot.loader.grub.gfxmodeEfi = "max";
        boot.loader.grub.useOSProber = true;
        boot.loader.grub.device = config.dotfiles.bootloader.grubDevice;
      })
    ];
  };
}

{ ... }: {
  # finix only ships limine (no systemd-boot). On a shared ESP limine installs
  # to efi/limine next to NixOS' systemd-boot and gets an entry to chainload it,
  # so the NixOS generations stay one menu item away.
  flake.finixModules.bootloader = { config, lib, modules, ... }: {
    imports = [ modules.limine ];

    assertions = [
      {
        assertion = config.dotfiles.bootloader.type == "systemd";
        message = "finix bootloader aspect: only EFI (dotfiles.bootloader.type = \"systemd\") is ported; it maps to limine.";
      }
    ];

    boot.loader.efi.canTouchEfiVariables = true;

    programs.limine = {
      enable = true;
      maxGenerations = 20;
      extraEntries = ''
        /NixOS (systemd-boot)
          protocol: efi
          path: boot():/EFI/systemd/systemd-bootx64.efi
      '';
    };
  };
}

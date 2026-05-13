{ inputs, ... }: {
  flake.nixosModules.theme = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.theme;
      schemeFile = "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
    in {
      imports = [ inputs.stylix.nixosModules.stylix ];

      # Set the scheme at the NixOS level (gives lib.stylix.colors in NixOS modules)
      stylix.base16Scheme = schemeFile;
      stylix.fonts.monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      stylix.opacity.terminal = 0.9;

      # Disable Stylix's automatic HM wiring. followSystem tries to set
      # home-manager.users.<name>.stylix.* before the HM module is evaluated,
      # causing "option does not exist" errors. We manage the HM side manually.
      stylix.homeManagerIntegration.autoImport = false;
      stylix.homeManagerIntegration.followSystem = false;

      # Load the Stylix HM module for all users and propagate settings.
      home-manager.sharedModules = [
        inputs.stylix.homeModules.default
        ({ lib, ... }: {
          stylix.base16Scheme = lib.mkDefault schemeFile;
          stylix.autoEnable = lib.mkDefault cfg.enable;
          stylix.fonts.monospace = lib.mkDefault {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font Mono";
          };
          stylix.opacity.terminal = lib.mkDefault 0.9;

          # Targets we control manually (colours via config.lib.stylix.colors refs)
          stylix.targets.waybar.enable = false;
          stylix.targets.mako.enable = false;
          stylix.targets.wofi.enable = false;
          stylix.targets.hyprlock.enable = false;
          stylix.targets.hyprpaper.enable = false;
          stylix.targets.gtk.enable = false;
          stylix.targets.neovim.enable = false;
        })
      ];
    };
}

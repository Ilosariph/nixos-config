{ inputs, ... }: {
  flake.nixosModules.theme = { config, lib, pkgs, ... }:
    let cfg = config.dotfiles.theme; in {
      imports = [ inputs.stylix.nixosModules.stylix ];

      # Always set a scheme so Stylix doesn't error when stylix.image is null
      stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";

      # autoEnable = false → all targets off; = true → targets auto-activate
      stylix.autoEnable = cfg.enable;

      # Monospace font to match existing JetBrains Mono setup
      stylix.fonts.monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };

      # Terminal opacity (kitty target picks this up)
      stylix.opacity.terminal = 0.9;

      # Targets handled manually or kept as-is
      stylix.targets.waybar.enable = false;
      stylix.targets.mako.enable = false;
      stylix.targets.wofi.enable = false;
      stylix.targets.hyprlock.enable = false;
      stylix.targets.hyprpaper.enable = false;
      stylix.targets.gtk.enable = false;
      stylix.targets.neovim.enable = false;
    };
}

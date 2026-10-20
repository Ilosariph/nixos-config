{ ... }: {
  flake.finixModules.kitty = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      environment.systemPackages = [ pkgs.kitty ];

      hjem.users.${config.dotfiles.user.name}.xdg.config.files."kitty/kitty.conf".text = ''
        include ${pkgs.kitty-themes}/share/kitty-themes/themes/tokyo_night_night.conf
        font_family Jetbrains Mono
        background_opacity 0.9
        shell ${pkgs.fish}/bin/fish
        shell_integration enabled
      '';
    };
}

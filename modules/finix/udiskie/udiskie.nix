{ ... }: {
  # udiskie runs from the compositor autostart (umbriel aspect)
  flake.finixModules.udiskie = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.udiskie.enable {
      environment.systemPackages = [ pkgs.udiskie ];

      hjem.users.${config.dotfiles.user.name}.xdg.config.files."udiskie/config.yml".source =
        (pkgs.formats.yaml { }).generate "udiskie.yml" {
          program_options = {
            file_manager = "${pkgs.kitty}/bin/kitty ${pkgs.yazi}/bin/yazi";
            automount = true;
            tray = "auto";
            notify = true;
          };
        };
    };
}

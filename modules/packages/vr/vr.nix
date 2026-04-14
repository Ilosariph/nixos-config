{ ... }: {
  flake.nixosModules.vr = { config, pkgs, lib, ... }:
    lib.mkIf config.dotfiles.programs.vr.enable {
      environment.systemPackages = with pkgs; [ android-tools ];

      services.wivrn = {
        enable = true;
        openFirewall = true;
        autoStart = true;
      };

      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        home.packages = [ pkgs.wayvr ];
        xdg.configFile."wlxoverlay/openxr_actions.json5".source = ./openxr_actions.json5;
      };
    };
}

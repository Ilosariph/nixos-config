{ ... }: {
  flake.nixosModules.mpv = { config, lib, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.mpv = {
          enable = true;
          config = {
            window-maximized = true;
            screenshot-dir = "~/Documents/enc";
            script-opts-add = "osc-visibility=always";
            keep-open = true;
            screenshot-template = "mpv-shot-%tY-%tm-%td-%tHh%tMm%tSs-%f";
            mute = false;
            ao = "pulse";
          };
          bindings = {
            "e" = "screenshot";
            "o" = "keypress CLOSE_WIN";
          };
        };
      };
    };
}

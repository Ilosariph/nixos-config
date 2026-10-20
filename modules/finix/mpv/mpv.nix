{ ... }: {
  flake.finixModules.mpv = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      environment.systemPackages = [ pkgs.mpv ];

      hjem.users.${config.dotfiles.user.name}.xdg.config.files = {
        "mpv/mpv.conf".text = ''
          ao=pulse
          keep-open=yes
          mute=no
          screenshot-dir=~/Documents/enc
          screenshot-template=mpv-shot-%tY-%tm-%td-%tHh%tMm%tSs-%f
          script-opts-add=osc-visibility=always
          window-maximized=yes
        '';
        "mpv/input.conf".text = ''
          e screenshot
          o keypress CLOSE_WIN
        '';
      };
    };
}

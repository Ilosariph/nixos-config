{ ... }: {
  # Package-only aspects from modules/packages (plezy, orca-slicer, darktable,
  # cad, thonny, gnirehtet, blog)
  flake.finixModules.apps = { config, lib, pkgs, ... }:
    let
      p = config.dotfiles.programs;
      desktop = config.dotfiles.desktop.enable;
    in lib.mkMerge [
      {
        environment.systemPackages =
          lib.optional p.plezy.enable pkgs.plezy
          ++ lib.optionals desktop [ pkgs.orca-slicer pkgs.darktable ]
          ++ lib.optional p.cad.kicad.enable pkgs.kicad
          ++ lib.optional p.cad.freecad.enable pkgs.freecad-wayland
          ++ lib.optional p.cad.openscad.enable pkgs.openscad
          ++ lib.optional p.cad.prusa-slicer.enable pkgs.prusa-slicer
          ++ lib.optional p.thonny.enable pkgs.thonny
          ++ lib.optionals p.gnirehtet.enable [
            pkgs.android-tools
            (pkgs.gnirehtet.overrideAttrs (old: {
              postInstall = ''
                wrapProgram $out/bin/gnirehtet \
                  --set GNIREHTET_APK ${old.passthru.apk}/gnirehtet.apk \
                  --set ADB ${pkgs.android-tools}/bin/adb
              '';
            }))
          ];
      }

      (lib.mkIf p.thonny.enable {
        users.groups.dialout = { };
        users.users.${config.dotfiles.user.name}.extraGroups = [ "dialout" ];
      })

      (lib.mkIf p.blog.enable {
        dotfiles.direnv.shells = [{
          dir = "blog";
          packages = [ pkgs.hugo pkgs.git ];
        }];
      })

      (lib.mkIf desktop {
        security.pam.environment.WALLPAPER_DIR.default = "${pkgs.runCommand "wallpapers" { } ''
          mkdir -p $out
          cp -r ${config.dotfiles.wallpapers.directory}/. $out/
        ''}";
      })
    ];
}

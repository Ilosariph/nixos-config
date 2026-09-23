{ ... }: {
  flake.nixosModules.cad = { config, lib, ... }:
    let
      cfg = config.dotfiles.programs.cad;
    in
    lib.mkIf (cfg.kicad.enable || cfg.freecad.enable || cfg.openscad.enable || cfg.prusa-slicer.enable) {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        home.packages = lib.optional cfg.kicad.enable pkgs.kicad
          ++ lib.optional cfg.freecad.enable pkgs.freecad-wayland
          ++ lib.optional cfg.openscad.enable pkgs.openscad
          ++ lib.optional cfg.prusa-slicer.enable pkgs.prusa-slicer;
      };
    };
}

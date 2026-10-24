{ ... }: {
  flake.nixosModules.orca-slicer = { config, lib, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        # WebKitGTK's dmabuf renderer → "Error 71 (Protocol error)" under Umbriel
        home.packages = [
          (pkgs.symlinkJoin {
            name = "orca-slicer";
            paths = [ pkgs.orca-slicer ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/orca-slicer --set WEBKIT_DISABLE_DMABUF_RENDERER 1
            '';
          })
        ];
      };
    };
}

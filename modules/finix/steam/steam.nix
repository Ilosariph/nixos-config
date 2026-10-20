{ inputs, ... }: {
  # Steam + gamescope from finix community-modules
  flake.finixModules.steam = { config, lib, pkgs, ... }: {
    imports = [ inputs.finix-community.nixosModules.steam ];

    config = lib.mkIf config.dotfiles.programs.steam.enable {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
        hardware.enable = true;
      };
      # The community module's default references programs.libudev/libseat,
      # which finix no longer has; with eudev the stock package is right anyway.
      programs.gamescope = {
        enable = true;
        package = pkgs.gamescope;
      };
      hardware.graphics.enable32Bit = true;
      environment.systemPackages = [ pkgs.protonup-qt ];
    };
  };
}

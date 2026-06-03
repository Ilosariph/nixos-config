{ ... }: {
  flake.nixosModules.steam = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.steam.enable {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = true;
      };
      programs.gamescope.enable = true;
      environment.systemPackages = [ pkgs.protonup-qt ];
    };
}

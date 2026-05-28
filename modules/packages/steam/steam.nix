{ ... }: {
  flake.nixosModules.steam = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.steam.enable {
			programs.gamescope.enable = true;
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
      };
    };
}

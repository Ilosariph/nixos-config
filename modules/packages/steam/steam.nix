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
      hardware.graphics.enable32Bit = true;
      environment.systemPackages = [ pkgs.protonup-qt ];

      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        xdg.desktopEntries.steam = {
          name = "Steam";
          exec = "steam";
          icon = "steam";
          terminal = false;
          type = "Application";
          categories = [ "Network" "FileTransfer" "Game" ];
          mimeType = [ "x-scheme-handler/steam" "x-scheme-handler/steamlink" ];
        };
      };
    };
}

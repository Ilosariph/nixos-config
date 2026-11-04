# One-off Ubuntu -> NixOS migration helper (docs/vps.md). pre-switch.sh runs
# on Ubuntu; this installs its counterpart. Off unless explicitly enabled, so
# nothing on prod can restore over /docker by accident.
{ config, lib, pkgs, ... }:
{
  options.dotfiles.vps.migration.enable = lib.mkEnableOption "the vps-migrate-restore command";

  config = lib.mkIf config.dotfiles.vps.migration.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "vps-migrate-restore";
        runtimeInputs = [ config.virtualisation.docker.package pkgs.gawk ];
        text = builtins.readFile ./migration/restore.sh;
      })
    ];
  };
}

# One-off Ubuntu -> NixOS migration helper (docs/nucserver.md). pre-switch.sh
# runs on Ubuntu; this installs its counterpart. Off unless explicitly enabled,
# so nothing can restore over the stacks by accident.
{ config, lib, pkgs, ... }:
{
  options.dotfiles.nucserver.migration.enable = lib.mkEnableOption "the nucserver-migrate-restore command";

  config = lib.mkIf config.dotfiles.nucserver.migration.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "nucserver-migrate-restore";
        runtimeInputs = [ config.virtualisation.docker.package pkgs.acl pkgs.attr pkgs.gawk pkgs.gnutar ];
        text = builtins.readFile ./migration/restore.sh;
      })
    ];
  };
}

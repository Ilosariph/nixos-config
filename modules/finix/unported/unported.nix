{ ... }: {
  # dotfiles options whose NixOS implementation has no finix equivalent yet.
  # They only warn, so hosts can share options.nix with their NixOS config.
  flake.finixModules.unported = { config, lib, pkgs, ... }:
    let
      d = config.dotfiles;
      unported = lib.filterAttrs (_: on: on) {
        "dotfiles.programs.vr (WiVRn service; wayvr + adb are still installed)" = d.programs.vr.enable;
        "dotfiles.programs.virtualisation (libvirtd)" = d.programs.virtualisation.enable;
        "dotfiles.audio.easyeffects (systemd user service)" = d.audio.easyeffects.enable;
        "dotfiles.vpn (NetworkManager WireGuard import activation script)" = d.vpn.enable;
        "dotfiles.services.backup (systemd timers)" = d.services.backup.enable;
        "dotfiles.services.fail2ban" = d.services.fail2ban.enable;
        "dotfiles.services.jellyfin (oci-containers)" = d.services.jellyfin.enable;
        "dotfiles.services.pangolinNewt" = d.services.pangolinNewt.enable;
        "dotfiles.services.nixEval" = d.services.nixEval.enable;
        "dotfiles.windowManager.type = niri" = d.desktop.enable && d.windowManager.type == "niri";
        "dotfiles.windowManager.statusbar = waybar (mako)" = d.desktop.enable && d.windowManager.statusbar == "waybar";
        "desktop printing (CUPS) and declarative flatpak apps" = d.desktop.enable;
      };
    in {
      warnings = lib.mapAttrsToList (what: _: "finix: ${what} is not ported, ignored.") unported;

      environment.systemPackages = lib.optionals d.programs.vr.enable [ pkgs.wayvr pkgs.android-tools ];
      hjem.users.${d.user.name}.xdg.config.files = lib.mkIf d.programs.vr.enable {
        "wlxoverlay/openxr_actions.json5".source = ../../packages/vr/openxr_actions.json5;
      };
    };
}

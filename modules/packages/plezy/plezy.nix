{ ... }: {
  flake.nixosModules.plezy = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.plezy.enable {
      # Plex/Jellyfin/Emby client. Server login is done in-app — connections
      # and auth tokens live in its own DB, so no declarative server config.
      home-manager.users.${config.dotfiles.user.name} = { lib, config, ... }:
        let
          # Plezy's embedded libmpv ignores mpv.conf, but applies its own
          # `mpv_config_text` (mpv.conf syntax) as properties after player
          # setup. Reuse programs.mpv.config minus options that don't fit:
          # no mpv window/OSC, app owns EOF handling + volume, and `ao` is
          # init-only (native pipewire routing is in audio-routing.nix).
          # input.conf bindings don't carry over — keybinds are in-app.
          mpvExcluded = [ "window-maximized" "script-opts-add" "keep-open" "mute" "ao" ];
          mpvValue = v:
            if lib.isBool v then (if v then "yes" else "no")
            else if lib.isList v then lib.concatMapStringsSep "," toString v
            else toString v;
          mpvConfigText = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${mpvValue v}")
            (lib.removeAttrs (lib.optionalAttrs config.programs.mpv.enable config.programs.mpv.config) mpvExcluded));

          # Merged into shared_preferences.json on activation. The file also
          # holds runtime state + credential_vault_key_v1, so it can't be a
          # read-only symlink — only these keys are forced, the rest is kept.
          settings = {
            default_playback_speed = 1.5;
            enable_hdr = false;
            default_box_fit_mode = 0;
            custom_download_path = "${config.home.homeDirectory}/Downloads";
            custom_download_path_type = "file";
            mpv_config_text = mpvConfigText;
          };
        in
        {
          home.packages = [ pkgs.plezy ];

          # Plezy rewrites the file from memory, so changes only stick if it
          # isn't running during activation.
          home.activation.plezySettings =
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              dir="$HOME/.local/share/com.edde746.plezy"
              conf="$dir/shared_preferences.json"
              ${pkgs.coreutils}/bin/mkdir -p "$dir"
              [ -f "$conf" ] || echo '{}' > "$conf"
              tmp="$(${pkgs.coreutils}/bin/mktemp)"
              ${pkgs.jq}/bin/jq -c --argjson s ${lib.escapeShellArg (builtins.toJSON settings)} '. * $s' "$conf" > "$tmp" \
                && ${pkgs.coreutils}/bin/mv "$tmp" "$conf"
            '';
        };
    };
}

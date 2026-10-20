{ ... }: {
  # Minimal sops-nix replacement. sops-nix's NixOS module needs systemd /
  # NixOS activation options, so on finix secrets are decrypted by an
  # activation script: `sops --decrypt --extract` per secret into its path.
  # Supports the subset this repo uses (path, owner, group, mode).
  flake.finixModules.sops = { config, lib, pkgs, ... }:
    let
      cfg = config.sops;

      install = name: s: ''
        install -d -m 0755 "$(dirname ${lib.escapeShellArg s.path})"
        tmp="$(mktemp ${lib.escapeShellArg s.path}.XXXXXX)"
        if SOPS_AGE_KEY_FILE=${lib.escapeShellArg cfg.age.keyFile} \
            sops --decrypt --extract '["${name}"]' ${s.sopsFile} > "$tmp"; then
          chown ${s.owner}:${s.group} "$tmp"
          chmod ${s.mode} "$tmp"
          mv -f "$tmp" ${lib.escapeShellArg s.path}
        else
          rm -f "$tmp"
          echo "sops: failed to decrypt ${name}" >&2
          _localstatus=1
        fi
      '';
    in {
      options.sops = {
        age.keyFile = lib.mkOption {
          type = lib.types.str;
          default = config.dotfiles.sops.ageKeyFile;
          description = "age private key used to decrypt secrets.";
        };
        defaultSopsFile = lib.mkOption {
          type = lib.types.path;
          default = config.dotfiles.sops.defaultSecretsFile;
          description = "Default sops file for secrets.";
        };
        secrets = lib.mkOption {
          default = { };
          description = "Secrets decrypted on activation (sops-nix compatible subset).";
          type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                default = "/run/secrets/${name}";
              };
              owner = lib.mkOption { type = lib.types.str; default = "root"; };
              group = lib.mkOption { type = lib.types.str; default = "root"; };
              mode = lib.mkOption { type = lib.types.str; default = "0400"; };
              sopsFile = lib.mkOption {
                type = lib.types.path;
                default = cfg.defaultSopsFile;
              };
            };
          }));
        };
      };

      config = lib.mkIf (config.dotfiles.sops.enable && cfg.secrets != { }) {
        system.activation.path = [ pkgs.sops pkgs.coreutils ];
        system.activation.scripts.setupSecrets = {
          deps = [ "users" "etc" ];
          text = ''
            install -d -m 0751 /run/secrets
            ${lib.concatStrings (lib.mapAttrsToList install cfg.secrets)}
          '';
        };
      };
    };
}

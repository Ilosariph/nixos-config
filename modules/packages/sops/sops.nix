{ inputs, ... }: {
  # Hosts decrypt with their own post-quantum age identity (age-keygen -pq,
  # ML-KEM-768 + X25519), generated at activation, so no key has to be copied
  # onto machines. Recipients live in nix-secrets/.sops.yaml; see
  # docs/secrets.md.
  flake.nixosModules.sops = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.sops;
      keyFile = lib.escapeShellArg cfg.ageKeyFile;
      pubFile = lib.escapeShellArg "${dirOf cfg.ageKeyFile}/key.pub";
      hasUserSecrets = lib.any (s: s.neededForUsers) (lib.attrValues config.sops.secrets);
    in
    lib.mkIf cfg.enable {
      # Per-host file: each host can only decrypt its own secrets (+ shared.yaml).
      dotfiles.sops.defaultSecretsFile = lib.mkDefault "${inputs.nix-secrets}/hosts/${cfg.host}.yaml";
      dotfiles.sops.sharedSecretsFile = lib.mkDefault "${inputs.nix-secrets}/shared.yaml";
      sops.defaultSopsFile = cfg.defaultSecretsFile;
      sops.age.keyFile = cfg.ageKeyFile;
      # No SSH host key import (classical X25519 / RSA).
      sops.age.sshKeyPaths = [ ];
      sops.gnupg.sshKeyPaths = [ ];

      environment.systemPackages = [ pkgs.age ];

      # Generate the key before sops-nix decrypts (also covers the very first
      # activation on a fresh install).
      system.activationScripts = lib.mkMerge [
        {
          sopsAgeKey = ''
            if [ ! -s ${keyFile} ]; then
              mkdir -p "$(dirname ${keyFile})"
              rm -f ${keyFile}
              (umask 077; ${pkgs.age}/bin/age-keygen -pq -o ${keyFile} 2>/dev/null)
            fi
            chmod 600 ${keyFile}
            # Public recipient for ./secrets.sh recipient (not secret).
            ${pkgs.age}/bin/age-keygen -y ${keyFile} > ${pubFile}.tmp
            chmod 644 ${pubFile}.tmp
            mv ${pubFile}.tmp ${pubFile}
          '';
        }
        # setupSecrets / setupSecretsForUsers only exist when there are
        # matching secrets. The mkIf must wrap the attr itself, or an empty one
        # (no text) is still defined.
        (lib.mkIf (config.sops.secrets != { }) {
          setupSecrets.deps = [ "sopsAgeKey" ];
        })
        (lib.mkIf hasUserSecrets {
          setupSecretsForUsers.deps = [ "sopsAgeKey" ];
        })
      ];
    };
}

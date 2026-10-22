{ inputs, ... }: {
  # Hosts decrypt with their SSH host key (converted to age by sops-nix), so no
  # age key file has to be copied onto machines. You edit with a YubiKey
  # (age-plugin-yubikey). Recipients live in nix-secrets/.sops.yaml; see
  # docs/secrets.md.
  flake.nixosModules.sops = { config, lib, pkgs, ... }:
    let
      hostKey = "/etc/ssh/ssh_host_ed25519_key";
    in
    lib.mkIf config.dotfiles.sops.enable {
      dotfiles.sops.defaultSecretsFile = lib.mkDefault "${inputs.nix-secrets}/secrets.yaml";
      sops.defaultSopsFile = config.dotfiles.sops.defaultSecretsFile;
      sops.age.sshKeyPaths = [ hostKey ];
      sops.age.keyFile = config.dotfiles.sops.ageKeyFile;
      # Only the ed25519 host key is a recipient; skip the RSA/GPG import.
      sops.gnupg.sshKeyPaths = [ ];

      environment.systemPackages = [ pkgs.ssh-to-age ];

      # Desktops don't run sshd, so nothing generates a host key there. Create it
      # before sops-nix decrypts (also covers the very first activation on a fresh
      # install, before sshd's own keygen runs). sshd reuses it when enabled.
      system.activationScripts.sopsHostKey = ''
        if [ ! -s ${hostKey} ]; then
          mkdir -p /etc/ssh
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f ${hostKey}
        fi
      '';
      # setupSecrets only exists when there are (non-neededForUsers) secrets.
      system.activationScripts.setupSecrets.deps =
        lib.mkIf (config.sops.secrets != { }) [ "sopsHostKey" ];
    };
}

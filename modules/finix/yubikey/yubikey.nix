{ ... }: {
  # finix counterpart of modules/packages/yubikey/yubikey.nix. finix PAM
  # services are plain text, so U2F is a `sufficient` pam_u2f line placed in
  # front of the sudo / polkit-1 stacks. LUKS FIDO2 unlock needs systemd stage-1
  # and is not available.
  flake.finixModules.yubikey = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.security.yubikey;
      u2fLine = ''
        auth sufficient ${pkgs.pam_u2f}/lib/security/pam_u2f.so authfile=/etc/u2f_keys cue
      '';
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.luks.enable;
          message = "finix: YubiKey LUKS unlock needs systemd stage-1 initrd (not available).";
        }
      ];

      environment.systemPackages = with pkgs; [
        yubikey-manager
        yubico-pam
        yubioath-flutter
        libfido2
        pam_u2f
      ];

      services.udev.packages = with pkgs; [
        yubikey-manager
        yubikey-personalization
        libu2f-host
      ];

      # smart card daemon (PIV / some FIDO operations); no finix module yet
      finit.services.pcscd = {
        description = "PC/SC smart card daemon";
        conditions = [ "service/udevd/ready" ];
        command = "${pkgs.pcsclite}/bin/pcscd --foreground";
        runtime-dir = "pcscd";
      };
      environment.etc."reader.conf.d/.keep".text = "";

      security.pam.services.sudo.text = lib.mkIf cfg.sudo.enable (lib.mkBefore u2fLine);
      security.pam.services.polkit-1.text = lib.mkIf cfg.systemAuth.enable (lib.mkBefore u2fLine);

      sops.secrets.yubikey-u2f-keys = lib.mkIf cfg.sudo.enable {
        path = "/etc/u2f_keys";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
}

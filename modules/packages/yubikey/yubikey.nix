{ ... }: {
  flake.nixosModules.yubikey = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.security.yubikey;
    in
    lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        yubikey-manager        # ykman - general management CLI
        yubico-pam             # pamu2fcfg - register U2F keys for sudo
				yubioath-flutter
				libfido2
				pam_u2f
      ];

      # udev rules so the YubiKey USB device is accessible without root
      services.udev.packages = with pkgs; [ 
					yubikey-manager
					yubikey-personalization
					libu2f-host
				];

      # smart card daemon (required for PIV and some FIDO operations)
      services.pcscd.enable = true;

      # --- LUKS unlocking via FIDO2 ---
      # Uses systemd stage-1 initrd; systemd-cryptsetup detects enrolled FIDO2
      # tokens from the LUKS2 header automatically — no per-device NixOS config
      # needed beyond pointing boot.initrd.luks.devices at the partition.
      boot.initrd.systemd.enable = lib.mkIf cfg.luks.enable true;

      # --- sudo via U2F ---
      # pam_u2f with control=sufficient: touching the YubiKey grants sudo;
      # if no key is present or auth fails, PAM falls through to password.
      # Login is not affected (no other service has u2fAuth = true).
      # Key file is managed via sops secret "yubikey-u2f-keys" → /etc/u2f_keys.
      # enable = false (default): u2fAuth defaults to false for all services.
      # Explicit u2fAuth = true below opts in only sudo and polkit-1.
      security.pam.u2f = lib.mkIf cfg.sudo.enable {
        settings = {
          authfile = "/etc/u2f_keys";
          cue = true;
        };
        control = "sufficient";
      };
      security.pam.services.sudo.u2fAuth = lib.mkIf cfg.sudo.enable true;

      sops.secrets.yubikey-u2f-keys = lib.mkIf cfg.sudo.enable {
        path = "/etc/u2f_keys";
        owner = "root";
        group = "root";
        mode = "0400";
      };

			# --- polkit system-auth prompts (e.g. 1Password re-auth, privilege dialogs) ---
      security.pam.services.polkit-1.u2fAuth = lib.mkIf cfg.systemAuth.enable true;
    };
}

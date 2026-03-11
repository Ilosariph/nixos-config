{ ... }: {
  flake.nixosModules.virtualisation = { config, pkgs, lib, ... }:
    let
      isEnabled = config.dotfiles.programs.virtualisation.enable;
    in lib.mkIf isEnabled {
      virtualisation.libvirtd = {
        enable = true;
        qemu.swtpm.enable = true;
      };
      users.groups.libvirtd.members = [ config.dotfiles.user.name ];
      users.groups.kvm.members = [ config.dotfiles.user.name ];

      # Workaround: libvirt upstream service unit hardcodes /usr/bin/sh (broken on NixOS).
      # The empty string clears the upstream ExecStart before appending the patched command
      # (required for Type=oneshot services where drop-ins append rather than replace).
      systemd.services.virt-secret-init-encryption.serviceConfig.ExecStart = lib.mkForce [
        ""
        "${pkgs.bash}/bin/sh -c 'umask 0077 && (dd if=/dev/random status=none bs=32 count=1 | systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
      ];

      home-manager.users.${config.dotfiles.user.name} = {
        home.packages = with pkgs; [ virt-manager virt-viewer ];
      };
    };
}

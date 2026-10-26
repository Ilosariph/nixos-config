{ inputs, ... }: {
  flake.nixosModules.yeetmouse = { config, lib, pkgs, ... }: {
    imports = [ inputs.yeetmouse.nixosModules.default ];

    config = lib.mkIf config.dotfiles.programs.yeetmouse.enable {
      # Upstream nix/package.nix still uses pkgs.xorg.xhost, which warns at eval
      # (xorg package set deprecated). Point it at top-level xhost until fixed.
      nixpkgs.overlays = [
        (final: prev: {
          xorg = prev.xorg // { inherit (prev) xhost; };
        })
      ];

      hardware.yeetmouse = {
        enable = true;
        sensitivity = 0.257;
        preScale = 1.0;
        mode.jump = {
          acceleration = 7.07;
          midpoint = 3.63;
          smoothness = 1.0;
          useSmoothing = true;
        };
      };

      users.groups.yeetmouse = {};
      users.users.${config.dotfiles.user.name}.extraGroups = [ "yeetmouse" ];

      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        xdg.desktopEntries.yeetmouse = {
          name = "Yeetmouse GUI";
          exec = "yeetmouse";
          categories = [ "Settings" "HardwareSettings" ];
          comment = "Yeetmouse Configuration Tool";
        };
      };

      systemd.services.yeetmouse-config = {
        description = "Apply yeetmouse acceleration parameters";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "yeetmouse-config-apply" ''
            until [ -d /sys/module/yeetmouse/parameters ]; do sleep 0.1; done
            ${pkgs.coreutils}/bin/chmod g+rw /sys/module/yeetmouse/parameters/*
            ${pkgs.coreutils}/bin/chgrp yeetmouse /sys/module/yeetmouse/parameters/*
            ${pkgs.systemd}/bin/udevadm trigger --subsystem-match=input --action=add
          '';
        };
      };
    };
  };
}

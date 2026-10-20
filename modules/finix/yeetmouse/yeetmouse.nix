{ inputs, ... }: {
  # The upstream module only touches boot.extraModulePackages,
  # environment.systemPackages and services.udev.extraRules (shimmed in the
  # compat aspect), so it is imported as-is. Its udev rule applies the
  # parameters whenever a mouse appears; the chgrp below lets the GUI write them.
  flake.finixModules.yeetmouse = { config, lib, pkgs, ... }: {
    imports = [ inputs.yeetmouse.nixosModules.default ];

    config = lib.mkIf config.dotfiles.programs.yeetmouse.enable {
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

      finit.tasks.yeetmouse-config = {
        description = "Apply yeetmouse parameter permissions";
        conditions = [ "service/udevd/ready" ];
        script = ''
          until [ -d /sys/module/yeetmouse/parameters ]; do sleep 0.1; done
          ${pkgs.coreutils}/bin/chmod g+rw /sys/module/yeetmouse/parameters/*
          ${pkgs.coreutils}/bin/chgrp yeetmouse /sys/module/yeetmouse/parameters/*
          ${config.services.udev.package}/bin/udevadm trigger --subsystem-match=input --action=add
        '';
      };

      hjem.users.${config.dotfiles.user.name}.xdg.data.files."applications/yeetmouse.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Yeetmouse GUI
        Exec=yeetmouse
        Categories=Settings;HardwareSettings;
        Comment=Yeetmouse Configuration Tool
      '';
    };
  };
}

{ pkgs, ... }:
{
  services.easyeffects.enable = true;

  imports = [
    ./mic-input-preset.nix
    ./output-comp.nix
  ];

  systemd.user.services.easyeffects = {
    Service = {
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "QT_QPA_PLATFORM=wayland"
      ];
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c 'until [ -S \${XDG_RUNTIME_DIR}/wayland-1 ]; do sleep 0.5; done'"
        "${pkgs.bash}/bin/bash -c 'rm -f /tmp/EasyEffectsServer /tmp/easyeffects.lock'"
      ];
    };
  };
}

# finix variant of ../mainpc/configuration.nix
{ pkgs, config, lib, ... }:
{
  boot.kernelModules = [ "coretemp" "nct6775" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="coretemp", ATTRS{temp1_label}=="Package id 0", RUN+="/bin/sh -c 'ln -s /sys$devpath/temp1_input /dev/cpu_temp'"
  '';

  services.udev.packages = with pkgs; [
    qmk-udev-rules
    vial
    via
    streamcontroller
    config.boot.kernelPackages.openrazer
  ];

  environment.systemPackages = with pkgs; [
    qmk
    qmk_hid
    qmk-udev-rules
    via
    vial
    losslesscut-bin
    musescore
    streamcontroller
    openrazer-daemon
    polychromatic
  ];

  # openrazer: NixOS runs openrazer-daemon as a systemd user service. On finix
  # only the kernel driver + udev rules are installed; the daemon is started
  # from the compositor autostart (dotfiles.windowManager.settings.execOnce).
  users.groups.openrazer = { };
  users.users.${config.dotfiles.user.name}.extraGroups = [ "openrazer" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.openrazer ];
  dotfiles.windowManager.settings.execOnce = [ "openrazer-daemon" ];

  hardware.nvidia = {
    enable = true;
    modesetting.enable = true;
    kernelModule = "closed";
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hjem.users.${config.dotfiles.user.name}.files.data = {
    source = "/data";
    type = "symlink";
  };
}

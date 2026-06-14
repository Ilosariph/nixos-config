{ lib, pkgs, ... }:
{
  dotfiles.sops.enable = true;
  dotfiles.sops.defaultSecretsFile = ../../../secrets/secrets.yaml;
  dotfiles.deploy.deployer.installTool = true;
  dotfiles.deploy.deployer.signingKeySecret = "mainpc-nix-signing-key";
  dotfiles.desktop.enable = true;
  dotfiles.programs.tmux.enable = false;
  dotfiles.windowManager.type = "niri";
  dotfiles.windowManager.displayManager = "greetd";
  dotfiles.programs.vr.enable = true;
  dotfiles.kernel = "gaming";
  dotfiles.programs.steam.enable = true;
  dotfiles.audio.routing = "pulsemeeter";
  dotfiles.audio.outputSink = "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y8PC38G1576D2F-00.Direct__Direct__sink";
  dotfiles.programs.thonny.enable = true;
  dotfiles.programs.blog.enable = true;
  dotfiles.programs.yeetmouse.enable = true;
  dotfiles.bluetooth.enable = true;
  dotfiles.security.yubikey.enable = true;
  dotfiles.security.yubikey.sudo.enable = true;
  dotfiles.security.yubikey.systemAuth.enable = true;
  dotfiles.windowManager.mainMonitor = "DP-3";
	dotfiles.windowManager.statusbar = "noctalia";
  dotfiles.windowManager.settings = {
    monitors = [
      "DP-3, 3440x1440@120, 0x0, 1"
      "DP-2, 1920x1080@144, -1920x0, 1"
      "HDMI-A-1, 1920x1200@59.95, 3440x0, 1"
    ];
  };
  dotfiles.windowManager.keyboardLayout = "colemak";
  dotfiles.windowManager.settings.execOnce = [
    "streamcontroller"
    "xrandr --output DP-3 --primary"
  ];
  dotfiles.direnv.shells = [
    {
      dir = "PycharmProjects";
      shellFile = ../../../shells/pycharm-python312.nix;
    }
    {
      dir = "PycharmProjects/motorized-faders";
      shellFile = ../../../shells/motorized-faders.nix;
    }
  ];

  dotfiles.network = {
    hostname = "simon-mainpc";
    interface = "eno1";
  };

  dotfiles.shares = [
    {
      mountPoint = "/mnt/projects";
      share = "p";
      credentials = "/etc/nixos/smb-p";
    }
    {
      mountPoint = "/mnt/simon";
      share = "simon_data";
      credentials = "/etc/nixos/smb-s";
    }
    {
      mountPoint = "/mnt/scan";
      share = "ScansLaserjet";
      server = "192.168.1.95";
      credentials = "/etc/nixos/smb-scan";
    }
  ];
}

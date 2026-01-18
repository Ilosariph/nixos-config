{ pkgs, config, ... }:
{
  imports = [
	  ./gaming/gaming.nix
	  ./drives.nix
	];
  boot.kernelModules = [ "coretemp" "nct6775" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="coretemp", ATTRS{temp1_label}=="Package id 0", RUN+="/bin/sh -c 'ln -s /sys$devpath/temp1_input /dev/cpu_temp'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6775.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm2 /dev/cpu_fan'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6775.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm2_input /dev/cpu_fan_input'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6774.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm6 /dev/case_fan'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6774.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm6_input /dev/case_fan_input'"
  '';

  systemd.services.fancontrol.enable = true;

  users.users.simon = {
    extraGroups = [ "openrazer" ];
  };
	hardware.openrazer = {
		enable = true;
	};

  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
		modesetting.enable = true;
		open = false;
		package = config.boot.kernelPackages.nvidiaPackages.stable;
	};
}

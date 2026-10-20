{ ... }: {
  # Small NixOS-compatible shims so shared code (and upstream NixOS modules
  # that only touch these options, e.g. yeetmouse) evaluates under finix.
  flake.finixModules.compat = { config, lib, pkgs, ... }: {
    options.services.udev.extraRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra udev rules, installed as 99-local.rules (NixOS services.udev.extraRules).";
    };

    config = lib.mkIf (config.services.udev.extraRules != "") {
      services.udev.packages = [
        (pkgs.writeTextDir "lib/udev/rules.d/99-local.rules" config.services.udev.extraRules)
      ];
    };
  };
}

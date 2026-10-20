{ inputs, lib, ... }: {
  # flake-parts only declares flake.nixosModules; finix aspects get their own
  # mergeable attrset so every file under modules/finix/ can add one.
  options.flake = inputs.flake-parts.lib.mkSubmoduleOptions {
    finixModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "finix modules (finit-based, no systemd), one per aspect.";
    };
  };
}

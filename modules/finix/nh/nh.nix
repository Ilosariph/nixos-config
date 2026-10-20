{ inputs, ... }: {
  # nh from finix community-modules; `nh clean` runs through the cron
  # scheduler provider (base aspect enables cron).
  flake.finixModules.nh = { ... }: {
    imports = [ inputs.finix-community.nixosModules.nh ];

    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        dates = "weekly";
        extraArgs = "--keep-since 7d --keep 5";
      };
    };
  };
}

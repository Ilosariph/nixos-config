{ ... }: {
  flake.nixosModules.nh = { ... }: {
    # nh: nicer wrapper around nixos-rebuild / home-manager / nix-collect-garbage
    # (build tree, closure diff, confirmation prompt). Used by build.sh.
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

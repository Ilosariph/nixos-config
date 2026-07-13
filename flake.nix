{
  description = "Configs for niri and server stuff";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Temporary pin for musescore: broken in current nixos-unstable
    # (makeCWrapper: Unknown argument --prefix LD_LIBRARY_PATH). Remove
    # once fixed upstream.
    nixpkgs-musescore.url = "github:nixos/nixpkgs/da5ad661ba4e5ef59ba743f0d112cbc30e474f32";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-xr = {
      url = "github:nix-community/nixpkgs-xr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TODO: noctalia v5 dropped the keybind-cheatsheet plugin; Mod+Slash bind
    # is commented out in niri.nix. Re-enable once a v5 cheatsheet plugin ships.
    noctalia-shell = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yeetmouse.url = "github:AndyFilter/YeetMouse?dir=nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Expose options.nix as a shared nixosModule picked up by all hosts
        { flake.nixosModules.options = ./options.nix; }
        # Auto-discover all aspect modules under modules/packages/
        (inputs.import-tree ./modules/packages)
        # Auto-discover all host instantiations (passed directly, bypassing _ skip)
        (inputs.import-tree ./modules/hosts)
      ];
      systems = [ "x86_64-linux" "aarch64-linux" ];
    };
}

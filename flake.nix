{
  description = "Home manager config";

  inputs = {
    nixpkgs = {
      url = "nixpkgs/nixos-25.05";
    };

    nixpkgsUnstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = {nixpkgs, nixpkgsUnstable, home-manager, hyprland, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      #pkgs = import nixpkgs { inherit system; };
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
        };
      };
      pkgsUnstable = import nixpkgs { inherit system; };
    in {
      nixosConfigurations = {
        simon = lib.nixosSystem {
          specialArgs = {
            inherit hyprland;
            inherit pkgsUnstable;
          };
          inherit system;
          inherit pkgs;
          modules = [ ./configuration.nix ];
        };
      };
      homeConfigurations = {
        simon = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home/home.nix ];
        };
      };
    };
}

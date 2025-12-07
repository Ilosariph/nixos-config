{
  description = "Home manager config";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hyprland.url = "github:hyprwm/Hyprland";

	elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

	nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";

	nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
	{
		nixpkgs,
		nixpkgs-unstable,
		home-manager,
		hyprland,
		walker,
		nixpkgs-xr,
		nix-flatpak,
		...
	}:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
	  };
    in
	{
      nixosConfigurations = {
        simonDesktop = lib.nixosSystem {
          specialArgs = {
            inherit hyprland;
            inherit pkgs-unstable;
          };
          inherit system;
          inherit pkgs;
          modules = [
			./general/config/configuration.nix
			./with-desktop/config/configuration.nix
			nixpkgs-xr.nixosModules.nixpkgs-xr
		  ];
        };
      };

      homeConfigurations = {
        simonDesktop = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs-unstable;
		  extraSpecialArgs = {
			pkgs-stable = pkgs;
			inherit walker;
		  };
          modules = [
			nix-flatpak.homeManagerModules.nix-flatpak
			./general/home/home.nix
			./with-desktop/home/home.nix
		  ];
        };
      };
    };
}

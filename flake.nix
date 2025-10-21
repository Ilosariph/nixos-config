{
  description = "Home manager config";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.05";
    };

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

	elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };
  };

  outputs =
	{
		nixpkgs,
		nixpkgs-unstable,
		home-manager,
		hyprland,
		walker,
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
        simon = lib.nixosSystem {
          specialArgs = {
            inherit hyprland;
            inherit pkgs-unstable;
          };
          inherit system;
          inherit pkgs;
          modules = [ ./configuration.nix ];
        };
      };

      homeConfigurations = {
        simon = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
		  extraSpecialArgs = {
			inherit pkgs-unstable;
			inherit walker;
		  };
          modules = [ ./home/home.nix ];
        };
      };
    };
}

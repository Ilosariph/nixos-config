{
	description = "Configs for hyprland, niri and server stuff";

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

		nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";

		nix-flatpak.url = "github:gmodena/nix-flatpak";

		dms = {
			url = "github:AvengeMedia/DankMaterialShell/stable";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

  outputs = {
		nixpkgs,
		nixpkgs-unstable,
		home-manager,
		hyprland,
		nixpkgs-xr,
		nix-flatpak,
		dms,
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
	in {
		nixosConfigurations = {
			hyprland = lib.nixosSystem {
				specialArgs = {
					inherit hyprland;
					inherit pkgs-unstable;
				};
				inherit system;
				inherit pkgs;
				modules = [
					./general/config/configuration.nix
					./with-desktop/config/configuration.nix
					./with-desktop/hyprland/configuration.nix
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
			};
			niri = lib.nixosSystem {
				specialArgs = {
					inherit hyprland;
					inherit pkgs-unstable;
				};
				inherit system;
				inherit pkgs;
				modules = [
					./general/config/configuration.nix
					./with-desktop/config/configuration.nix
					./with-desktop/niri/configuration.nix#todo change
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
			};
		};

		homeConfigurations = {
			hyprland = home-manager.lib.homeManagerConfiguration {
				pkgs = pkgs-unstable;
				extraSpecialArgs = {
					pkgs-stable = pkgs;
					inherit dms;
				};
				modules = [
					nix-flatpak.homeManagerModules.nix-flatpak
					./general/home/home.nix
					./with-desktop/home/home.nix
					./with-desktop/hyprland/home.nix
				];
			};
			niri = home-manager.lib.homeManagerConfiguration {
				pkgs = pkgs-unstable;
				extraSpecialArgs = {
					pkgs-stable = pkgs;
					inherit dms;
				};
				modules = [
					nix-flatpak.homeManagerModules.nix-flatpak
					./general/home/home.nix
					./with-desktop/home/home.nix
					./with-desktop/niri/home.nix
				];
			};
		};
	};
}

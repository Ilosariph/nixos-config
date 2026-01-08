{
	description = "Configs for hyprland, niri and server stuff";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
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
	
		nixos-conf = { desktop, pc, extraSpecialArgs ? {}, extraModules ? [] }:
			lib.nixosSystem { 
				specialArgs = {
				} // extraSpecialArgs;

				inherit system;
				inherit pkgs;
				modules = [
					./${desktop}/machines/${pc}/configuration.nix
					./${desktop}/machines/${pc}/hardware-configuration.nix
					./general/config/configuration.nix
					./${desktop}/config/configuration.nix
				] ++ extraModules;
			};

		home-manager-conf = { desktop, pc, extraSpecialArgs ? {}, extraModules ? [] }:
			home-manager.lib.homeManagerConfiguration {
				inherit pkgs;
				extraSpecialArgs = {
					pkgs-stable = pkgs;
				} // extraSpecialArgs;
				modules = [
					./general/home/home.nix
					./${desktop}/machines/${pc}/home.nix
					./${desktop}/home/home.nix
				] ++ extraModules;
		};

		nixos-conf-with-desktop = { pc, extraSpecialArgs ? {}, extraModules ? [] }:
			nixos-conf {
				desktop = "with-desktop";
				inherit pc;
				inherit extraSpecialArgs;
				inherit extraModules;
			};

		home-manager-conf-with-desktop = { pc, extraSpecialArgs ? {}, extraModules ? [] }:
			home-manager-conf {
				desktop = "with-desktop";
				inherit pc;
				extraSpecialArgs = {
					inherit dms;
				};
				extraModules = [
					nix-flatpak.homeManagerModules.nix-flatpak
				] ++ extraModules;
			};

	in {
		nixosConfigurations = {
			hyprland-mainpc = (nixos-conf-with-desktop {
				pc = "mainpc";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModules = [
					./with-desktop/hyprland/configuration.nix
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
			});
			hyprland-laptop = (nixos-conf-with-desktop {
				pc = "laptop";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModules = [
					./with-desktop/hyprland/configuration.nix
				];
			});
			niri-mainpc = (nixos-conf-with-desktop {
				pc = "mainpc";
				extraModules = [
					./with-desktop/niri/configuration.nix#todo change
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
			});

			nucserver = (nixos-conf {
				desktop = "no-desktop";
				pc = "nucserver";
			});
			laptopserver = (nixos-conf {
				desktop = "no-desktop";
				pc = "laptopserver";
			});
		};

		homeConfigurations = {
			hyprland-mainpc = (home-manager-conf-with-desktop {
			 pc = "mainpc";
				extraModules = [
					./with-desktop/hyprland/home.nix
					./with-desktop/machines/mainpc/hypr.nix
				];
			});
			hyprland-laptop = (home-manager-conf-with-desktop {
			 pc = "laptop";
				extraModules = [
					./with-desktop/hyprland/home.nix
					./with-desktop/machines/laptop/hypr.nix
				];
			});
			niri-mainpc = (home-manager-conf-with-desktop {
			 pc = "mainpc";
				extraModules = [
					./with-desktop/niri/home.nix
				];
			});

			nucserver = (home-manager-conf-with-desktop {
			 pc = "nucserver";
			});
			laptopserver = (home-manager-conf-with-desktop {
			 pc = "laptopserver";
			});
		};
	};
}

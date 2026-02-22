{
	description = "Configs for hyprland, niri and server stuff";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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
	};

  outputs = {
		nixpkgs,
		home-manager,
		nixpkgs-xr,
		nix-flatpak,
		sops-nix,
		...
	}:
	let
		lib = nixpkgs.lib;

		nixos-conf = { desktop, pc, windowManager ? null, username, system ? "x86_64-linux", extraModulesNixos ? [], extraModulesHome ? [] }:
			let
				pkgs = import nixpkgs {
					inherit system;
					config = {
						allowUnfree = true;
					};
				};
			in
			lib.nixosSystem {
				specialArgs = {
					inherit pc;
				};

				inherit system;
				inherit pkgs;
				modules = [
					sops-nix.nixosModules.sops
					./options.nix
					./${desktop}/machines/${pc}/options.nix
					./${desktop}/machines/${pc}/configuration.nix
					./${desktop}/machines/${pc}/hardware-configuration.nix
					./general/bootloader/default.nix
					./general/vpn.nix
					./general/config/configuration.nix
					./${desktop}/config/configuration.nix
				] ++ (
					if desktop == "with-desktop" then [
						./with-desktop/${windowManager}/configuration.nix
					] else []
				) ++ [
					home-manager.nixosModules.home-manager
					{
						home-manager.useGlobalPkgs = true;
						home-manager.useUserPackages = true;
						home-manager.backupFileExtension = "backup";
						home-manager.users.${username} = {
							imports = [
								./general/home/home.nix
								./${desktop}/machines/${pc}/home.nix
								./${desktop}/home/home.nix
							] ++ (
								if desktop == "with-desktop" then [
									./with-desktop/${windowManager}/home.nix
									nix-flatpak.homeManagerModules.nix-flatpak

								] else []
							) ++ extraModulesHome;
						};
					}
				] ++ extraModulesNixos;
			};

	in {
		nixosConfigurations = {
			hyprland-mainpc = (nixos-conf {
				desktop = "with-desktop";
				pc = "mainpc";
				windowManager = "hyprland";
				username = "simon";
				extraModulesNixos = [
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
				extraModulesHome = [
				];
			});
			hyprland-laptop = (nixos-conf {
				desktop = "with-desktop";
				pc = "laptop";
				windowManager = "hyprland";
				username = "simon";
				extraModulesNixos = [
				];
				extraModulesHome = [
				];
			});
			hyprland-macbook = (nixos-conf {
				desktop = "with-desktop";
				pc = "macbook";
				windowManager = "hyprland";
				system = "aarch64-linux";
				username = "simon";
				extraModulesNixos = [
				];
				extraModulesHome = [
				];
			});
			niri-mainpc = (nixos-conf {
				desktop = "with-desktop";
				pc = "mainpc";
				windowManager = "niri";
				username = "simon";
				extraModulesNixos = [
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
				extraModulesHome = [
				];
			});

			nucserver = (nixos-conf {
				desktop = "no-desktop";
				pc = "nucserver";
				username = "simon";
			});
			laptopserver = (nixos-conf {
				desktop = "no-desktop";
				pc = "laptopserver";
				username = "simon";
			});
		};
	};
}

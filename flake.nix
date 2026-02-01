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

		sops-nix.url = "github:Mic92/sops-nix";
	};

  outputs = {
		nixpkgs,
		home-manager,
		hyprland,
		nixpkgs-xr,
		nix-flatpak,
		dms,
		sops-nix,
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

		nixos-conf = { desktop, pc, bootloader ? null, username, extraSpecialArgs ? {}, extraModulesNixos ? [], extraModulesHome ? [] }:
			lib.nixosSystem {
				specialArgs = {
					pkgs-stable = pkgs;
				} // extraSpecialArgs;

				inherit system;
				inherit pkgs;
				modules = [
					sops-nix.nixosModules.sops
					./${desktop}/machines/${pc}/configuration.nix
					./${desktop}/machines/${pc}/hardware-configuration.nix
				] ++ (lib.optional (bootloader != null) ./general/bootloader/${bootloader}.nix) ++ [
					./general/config/configuration.nix
					./${desktop}/config/configuration.nix

					home-manager.nixosModules.home-manager
					{
						home-manager.useGlobalPkgs = true;
						home-manager.useUserPackages = true;
						home-manager.users.${username} = {
							imports = [
								./general/home/home.nix
								./${desktop}/machines/${pc}/home.nix
								./${desktop}/home/home.nix
							] ++ (
								if desktop == "with-desktop" then [
									nix-flatpak.homeManagerModules.nix-flatpak
									dms.homeModules.dankMaterialShell.default
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
				bootloader = "systemd";
				username = "simon";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModulesNixos = [
					./with-desktop/hyprland/configuration.nix
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
				extraModulesHome = [
					./with-desktop/hyprland/home.nix
					./with-desktop/machines/mainpc/hypr.nix
				];
			});
			hyprland-laptop = (nixos-conf {
				desktop = "with-desktop";
				pc = "laptop";
				bootloader = "grub";
				username = "simon";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModulesNixos = [
					./with-desktop/hyprland/configuration.nix
				];
				extraModulesHome = [
					./with-desktop/hyprland/home.nix
					./with-desktop/machines/laptop/hypr.nix
				];
			});
			niri-mainpc = (nixos-conf {
				desktop = "with-desktop";
				pc = "mainpc";
				bootloader = "systemd";
				username = "simon";
				extraModulesNixos = [
					./with-desktop/niri/configuration.nix #todo change
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
				extraModulesHome = [
					./with-desktop/niri/home.nix
				];
			});

			nucserver = (nixos-conf {
				desktop = "no-desktop";
				pc = "nucserver";
				bootloader = "systemd";
				username = "simon";
			});
			laptopserver = (nixos-conf {
				desktop = "no-desktop";
				pc = "laptopserver";
				bootloader = "grub";
				username = "simon";
			});
		};
	};
}

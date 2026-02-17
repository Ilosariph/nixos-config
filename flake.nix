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

		nixos-conf = { desktop, pc, bootloader ? "systemd", windowManager ? null, username, system ? "x86_64-linux", extraSpecialArgs ? {}, extraModulesNixos ? [], extraModulesHome ? [] }:
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
					pkgs-stable = pkgs;
				} // extraSpecialArgs;

				inherit system;
				inherit pkgs;
				modules = [
					sops-nix.nixosModules.sops
					./${desktop}/machines/${pc}/configuration.nix
					./${desktop}/machines/${pc}/hardware-configuration.nix
					./general/bootloader/${bootloader}.nix
					./general/config/configuration.nix
					./${desktop}/config/configuration.nix
				] ++ (
					if desktop == "with-desktop" then [
						./with-desktop/${windowManager}/configuration.nix
					] else []
				)++ [
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
									./with-desktop/${windowManager}/home.nix
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
				windowManager = "hyprland";
				username = "simon";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModulesNixos = [
					nixpkgs-xr.nixosModules.nixpkgs-xr
				];
				extraModulesHome = [
					./with-desktop/machines/mainpc/hypr.nix
				];
			});
			hyprland-laptop = (nixos-conf {
				desktop = "with-desktop";
				pc = "laptop";
				bootloader = "grub";
				windowManager = "hyprland";
				username = "simon";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModulesNixos = [
				];
				extraModulesHome = [
					./with-desktop/machines/laptop/hypr.nix
				];
			});
			hyprland-macbook = (nixos-conf {
				desktop = "with-desktop";
				pc = "macbook";
				bootloader = "systemd";
				windowManager = "hyprland";
				system = "aarch64-linux";
				username = "simon";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModulesNixos = [
				];
				extraModulesHome = [
					./with-desktop/machines/macbook/hypr.nix
				];
			});
			niri-mainpc = (nixos-conf {
				desktop = "with-desktop";
				pc = "mainpc";
				bootloader = "systemd";
				windowManager = "niri";
				username = "simon";
				extraModulesNixos = [
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

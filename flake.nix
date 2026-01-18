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
	
		nixos-conf = { desktop, pc, bootloader, extraSpecialArgs ? {}, extraModules ? [] }:
			lib.nixosSystem { 
				specialArgs = {
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

		nixos-conf-with-desktop = { pc, bootloader, extraSpecialArgs ? {}, extraModules ? [] }:
			nixos-conf {
				desktop = "with-desktop";
				inherit pc;
				inherit bootloader;
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
				bootloader = "systemd";
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
				bootloader = "grub";
				extraSpecialArgs = {
					inherit hyprland;
				};
				extraModules = [
					./with-desktop/hyprland/configuration.nix
				];
			});
			niri-mainpc = (nixos-conf-with-desktop {
				pc = "mainpc";
				bootloader = "systemd";
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
				bootloader = "grub";
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

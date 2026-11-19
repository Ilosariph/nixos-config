{ inputs, config, ... }: {
  flake.nixosConfigurations.evo = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      inputs.comfyui-nix.nixosModules.default
      # mslk >= 1.4.0 declares flydsl (unpackaged) as a mandatory dep when it
      # detects ROCm torch → pythonRuntimeDepsCheck fails. FlyDSL is an optional
      # backend at runtime (triton fallback), so rebuild the rocm72 set with the
      # dep dropped. Remove once comfyui-nix/nixpkgs handle it.
      ({ pkgs, lib, ... }:
        let
          src = inputs.comfyui-nix;
          versions = import "${src}/nix/versions.nix";
          upstream = import "${src}/nix/python-overrides.nix" {
            inherit pkgs versions;
            gpuSupport = "rocm";
            rocmChannel = "rocm72";
          };
          dropFlydsl = final: prev: lib.optionalAttrs (prev ? mslk) {
            mslk = prev.mslk.overridePythonAttrs (old: {
              pythonRemoveDeps = (old.pythonRemoveDeps or [ ]) ++ [ "flydsl" ];
            });
          } // lib.optionalAttrs (prev ? xformers) {
            # test_mslk_compat imports xformers.ops.fmha._triton.splitk_kernels,
            # which needs triton (not in the rocm72 set) → ModuleNotFoundError.
            xformers = prev.xformers.overridePythonAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "test_reexports_exist_in_mslk" ];
            });
          };
        in {
          services.comfyui.packageSet.rocm72 = lib.mkForce (import "${src}/nix/packages.nix" {
            inherit pkgs lib versions;
            gpuSupport = "rocm";
            pythonOverrides = lib.composeExtensions upstream dropFlydsl;
          }).default;
        })
      inputs.nix-private.nixosModules.evo
      (inputs.import-tree ../machines/evo)
    ] ++ (builtins.attrValues config.flake.nixosModules) ++ [
      {
        home-manager.users.simon.imports = [
          ../machines/evo/_home.nix
        ];
      }
    ];
  };
}

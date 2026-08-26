# Asahi "fairydust" kernel — experimental DisplayPort over USB-C.
#
# The released Asahi kernel (linux-asahi from nixos-apple-silicon) cannot drive
# an external display over USB-C; that work lives on the `fairydust` branch of
# AsahiLinux/linux. Replacing the `linux-asahi` package set makes the whole
# apple-silicon-support module follow along: boot.kernelPackages, the initrd
# module list, and the DTBs that get baked into m1n1 (boot-m1n1 concatenates
# dtbs/apple/*.dtb out of boot.kernelPackages.kernel) all come from here.
#
# Caveats:
#   - Experimental. Only one USB-C port per machine is enabled for DP, so a
#     second USB-C display won't work, and cold/hot plug is quirky.
#   - nixos-apple-silicon.cachix.org has no build of this kernel, so the first
#     rebuild after switching compiles it locally — expect a long build.
#   - `version` below must match the Makefile of the pinned branch. After a
#     `nix flake update linux-asahi-fairydust`, check
#     https://raw.githubusercontent.com/AsahiLinux/linux/fairydust/Makefile
#     and bump it, or the build fails on a modDirVersion mismatch.
#
# The expression mirrors apple-silicon-support/packages/linux-asahi/default.nix
# from nixos-apple-silicon. It has to be copied rather than `.override`n: that
# file's argument set has no `...`, so `src` cannot be passed through it. Re-sync
# the kernel config below if upstream changes it.
{ inputs, ... }:
{
  nixpkgs.overlays = [
    (final: _prev: {
      linux-asahi = final.callPackage (
        {
          lib,
          callPackage,
          linuxPackagesFor,
          _kernelPatches ? [ ],
        }:
        let
          linux-asahi-fairydust =
            {
              stdenv,
              lib,
              buildLinux,
              ...
            }:
            buildLinux rec {
              inherit stdenv lib;

              pname = "linux-asahi";
              version = "7.1.9";
              modDirVersion = version;
              extraMeta.branch = "7.1";

              src = inputs.linux-asahi-fairydust;

              kernelPatches = [
                {
                  name = "Asahi config";
                  patch = null;
                  structuredExtraConfig = with lib.kernel; {
                    # Needed for GPU
                    ARM64_16K_PAGES = yes;

                    ARM64_MEMORY_MODEL_CONTROL = yes;
                    ARM64_ACTLR_STATE = yes;

                    # Might lead to the machine rebooting if not loaded soon enough
                    APPLE_WATCHDOG = yes;

                    # Can not be built as a module, defaults to no
                    APPLE_M1_CPU_PMU = yes;

                    # Defaults to 'y', but we want to allow the user to set options in modprobe.d
                    HID_APPLE = module;

                    APPLE_PMGR_MISC = yes;
                    APPLE_PMGR_PWRSTATE = yes;
                  };
                  features.rust = true;
                }
              ]
              ++ _kernelPatches;
            };
        in
        lib.recurseIntoAttrs (linuxPackagesFor (callPackage linux-asahi-fairydust { }))
      ) { };
    })
  ];
}

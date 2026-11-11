# Aurora (Omarchy M) Apple Silicon stack — DRAFT, edge/testing upstream.
#
# Source: aurora-silicon/nixos-aurora (flake input `nixos-aurora`, consumed as
# plain files). It pins the Aurora kernel (aurora-silicon/linux), aura (their
# m1n1 fork, which forwards the macOS preboot UUID) and u-boot, plus the
# Touch ID userspace (apple_sep loader, patched libfprint/fprintd).
#
# Only the hardware pieces are taken, not Aurora's whole NixOS profile
# (nixosModules.default switches to GRUB, KDE, Plymouth, its own mesa/pipewire
# etc.):
#   dotfiles.aurora.enable          kernel + aura + u-boot (overlay subset),
#                                   runtime ESP firmware handoff (firmware.nix)
#   dotfiles.aurora.touchId.enable  SEP / Touch ID units + PAM (sep.nix):
#                                   sudo + polkit via pam_fprintd; Noctalia lock
#                                   screen via fprintd D-Bus (noctalia.nix)
# Upstream module files are called directly and their config wrapped in mkIf,
# so they follow `nix flake update nixos-aurora` without being copied.
#
# Caveats:
#   - Kernel is built against our nixpkgs, not Aurora's pin, so their binary
#     cache will mostly miss: expect a local kernel + aura build.
#   - Firmware is extracted at boot from the ESP into /run/aurora-firmware
#     instead of being baked from ./firmware (initrd systemd unit).
#   - Touch ID calibration is built on-device by `aurora-touchid-setup` from
#     the iBoot System Container; enclave state in /var/lib/aurora-sep* must
#     be kept. 13" M1 Pro is NOT a hardware-qualified model upstream.
#   - SEP state is shared with macOS (keybag, xART): back up macOS first.
{ inputs, config, lib, pkgs, ... }@args:
let
  cfg = config.dotfiles.aurora;
  src = inputs.nixos-aurora;
  auroraOverlay = import "${src}/overlay.nix";
  # Take only the named attrs from Aurora's overlay; it also replaces mesa,
  # pipewire, plymouth, docker, steam, ... which we don't want.
  # (mesa is taken: needed for the Aurora GPU driver.)
  pick = names: final: prev: lib.getAttrs names (auroraOverlay final prev);
  # Aurora's modules apply unconditionally; call them and keep the config only.
  firmwareModule = import "${src}/modules/firmware.nix" args;
  sepModule = import "${src}/modules/sep.nix" args;
in
{
  # aurora.sep.* options + nixpkgs' fprintAuth default flipped to off (no-op
  # while fprintd is disabled).
  options = sepModule.options;

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.enable && config.dotfiles.asahiFairydust.enable);
          message = "dotfiles.aurora.enable and dotfiles.asahiFairydust.enable both replace linux-asahi; pick one.";
        }
        {
          assertion = cfg.touchId.enable -> cfg.enable;
          message = "dotfiles.aurora.touchId.enable needs the Aurora kernel (dotfiles.aurora.enable).";
        }
      ];
    }

    (lib.mkIf cfg.enable (lib.mkMerge [
      {
        # After apple-silicon's overlay: aura wraps prev.m1n1, u-boot overrides
        # prev.uboot-asahi.
        nixpkgs.overlays = lib.mkAfter [
          # mesa: the Aurora kernel's GPU driver is named "aurora" (display is
          # a separate apple-drm card); stock Asahi mesa doesn't bind to it,
          # so compositors get no GPU.
          (pick [ "linux-asahi" "aurora-bindgen" "m1n1" "uboot-asahi" "mesa" "aurora-rusticl" ])
        ];

        nix.settings = {
          extra-substituters = [ "https://aurorasilicon.org/nixos-aurora/cache" ];
          extra-trusted-public-keys = [ (lib.removeSuffix "\n" (builtins.readFile "${src}/keys/cache.pub")) ];
        };

        # Aurora's kernel builds EFI_STUB=y but its `features` set drops
        # nixpkgs' efiBootStub flag, which systemd-boot asserts on.
        # apple-silicon passes boot.kernelPatches as linux-asahi's _kernelPatches.
        boot.kernelPatches = [
          {
            name = "aurora-efi-stub-feature";
            patch = null;
            features.efiBootStub = true;
          }
        ];
        # nixpkgs' default initrd modules (ata_piix, sata_*, ...) don't exist
        # in the Aurora kernel and fail the initrd build. Use Aurora's explicit
        # Apple/USB/NVMe set instead, read from its own module.
        boot.initrd.includeDefaultModules = false;
        # + dwc3-apple: the Aurora kernel's USB-C glue (apple,t8103-dwc3), not
        # in Aurora's list; without it there's no USB in stage 1, so the
        # YubiKey isn't seen and FIDO2 LUKS unlock falls back to passphrase.
        boot.initrd.availableKernelModules =
          (import "${src}/modules/aurora.nix" args).config.boot.initrd.availableKernelModules
          ++ [ "dwc3-apple" ];
        # No TPM on Apple Silicon and none in the Aurora kernel.
        boot.initrd.systemd.tpm2.enable = false;
        # Aurora kernel has no PS/2 driver and builds schedutil in.
        environment.etc."modules-load.d/nixos.conf".source = lib.mkForce (pkgs.writeText "nixos.conf"
          (lib.concatStringsSep "\n" (lib.subtractLists [ "atkbd" "cpufreq_schedutil" ] config.boot.kernelModules) + "\n"));
      }
      firmwareModule
    ]))

    (lib.mkIf (cfg.enable && cfg.touchId.enable) (lib.mkMerge [
      {
        nixpkgs.overlays = lib.mkAfter [
          (pick [ "aurora-sep" "aurora-touchid-rearm" "aurora-xart" "aurora-sep-sk" "libfprint" "fprintd" ])
          # aurora-touchid-setup carves the FSCl calibration from the raw iSC,
          # which breaks when its APFS extents aren't contiguous (J293: SEP
          # refuses it, 0x1c). Prefer the Hardware volume's FSCl-<serial> record.
          (final: prev: {
            aurora-sep = prev.aurora-sep.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./patches/aurora-touchid-fscl-records.patch ];
            });
          })
        ];
      }
      sepModule.config
    ]))
  ];
}

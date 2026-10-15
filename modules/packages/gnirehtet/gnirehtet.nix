{ ... }: {
  flake.nixosModules.gnirehtet = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.gnirehtet.enable {
      # nixpkgs wraps gnirehtet with Google's prebuilt adb (x86_64-only, unfree);
      # use android-tools' source-built adb so it also works on aarch64.
      environment.systemPackages = [
        pkgs.android-tools
        (pkgs.gnirehtet.overrideAttrs (old: {
          postInstall = ''
            wrapProgram $out/bin/gnirehtet \
              --set GNIREHTET_APK ${old.passthru.apk}/gnirehtet.apk \
              --set ADB ${pkgs.android-tools}/bin/adb
          '';
        }))
      ];
    };
}

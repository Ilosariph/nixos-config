{ ... }: {
  flake.nixosModules.orca-slicer = { config, lib, ... }:
    let
      extraCerts = config.dotfiles.programs.orcaSlicer.extraPrinterCerts;
    in
    lib.mkIf config.dotfiles.desktop.enable {
      # Bambu-protocol printers announce themselves via SSDP on UDP 2021 (device discovery).
      networking.firewall.allowedUDPPorts = [ 2021 ];

      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }:
        let
          orig = pkgs.orca-slicer;
          # The resources dir (incl. cert/printer.cer, the CA bundle printer TLS is checked against)
          # is compiled in as an absolute store path. Rebuilding just to append a cert takes ages,
          # so: same-name derivation (-> same-length $out), symlink everything, copy the binaries
          # with the old store path swapped for $out, and replace printer.cer.
          withCerts = pkgs.runCommand orig.name { } ''
            cp -rs ${orig} $out
            chmod -R u+w $out
            for f in $out/bin/* $out/bin/.*-wrapped; do
              [ -L "$f" ] || continue
              rm "$f"
              sed "s|${orig}|$out|g" "${orig}/bin/$(basename "$f")" > "$f"
              chmod 555 "$f"
            done
            cer=$out/share/OrcaSlicer/cert/printer.cer
            rm $cer
            cat ${orig}/share/OrcaSlicer/cert/printer.cer > $cer
            # "${"$"}{c}" (not toString) so each cert is imported into the store and the sandbox sees it
            for c in ${lib.concatMapStringsSep " " (c: lib.escapeShellArg "${c}") extraCerts}; do
              echo >> $cer
              cat "$c" >> $cer
            done
          '';
        in
        {
          # WebKitGTK's dmabuf renderer → "Error 71 (Protocol error)" under Umbriel
          home.packages = [
            (pkgs.symlinkJoin {
              name = "orca-slicer";
              paths = [ (if extraCerts == [ ] then orig else withCerts) ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/orca-slicer --set WEBKIT_DISABLE_DMABUF_RENDERER 1
              '';
            })
          ];
        };
    };
}

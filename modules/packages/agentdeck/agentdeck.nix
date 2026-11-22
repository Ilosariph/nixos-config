{ inputs, ... }: {
  # AgentDeck: controller daemon for Claude Code sessions with ESP32 boards
  # (https://github.com/puritysb/AgentDeck). Built from the own fork (flake input
  # `agentdeck`, branch waveshare-349): Waveshare ESP32-S3-Touch-LCD-3.49 port,
  # push-to-talk voice drafts, tmux voice delivery and permission answers.
  # After pushing to it: `nix flake update agentdeck`.
  #
  # Only the daemon (`agentdeck`) is packaged. Board firmware is flashed from
  # ~/Projects/AgentDeck (podman, env waveshare_349). Claude hooks are installed
  # once with `agentdeck hooks install` (plain curl; AGENTDECK_PORT=9120 in
  # ~/.claude/settings.json spares them python3).
  flake.nixosModules.agentdeck = { config, lib, pkgs, ... }:
    let
      nodejs = pkgs.nodejs_24;
      pnpm = pkgs.pnpm_11.override { inherit nodejs; };
      workspaces = [ "@agentdeck/bridge..." "@agentdeck/dot-relay" ];

      agentdeck = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "agentdeck";
        version = "0-unstable-${inputs.agentdeck.shortRev}";
        src = inputs.agentdeck;

        pnpmWorkspaces = workspaces;
        pnpmDeps = pkgs.fetchPnpmDeps {
          inherit (finalAttrs) pname version src pnpmWorkspaces;
          inherit pnpm;
          fetcherVersion = 5;
          hash = "sha256-Q10c09BAW+b4z24IU48K7W+wC8cCjhkaUA5Syh9WMis=";
        };

        nativeBuildInputs = [
          nodejs
          pnpm
          pkgs.pnpmConfigHook
          pkgs.python3 # node-gyp (better-sqlite3)
          pkgs.makeWrapper
        ];

        buildPhase = ''
          runHook preBuild
          # Install scripts were skipped (offline); compile the one native
          # addon the daemon needs (pairing token store, APME) against nodejs.
          pushd node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3
          ${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --release --nodedir=${nodejs}
          popd
          pnpm --filter @agentdeck/shared build
          pnpm --filter @agentdeck/hooks build
          pnpm --filter @agentdeck/bridge build
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          # The bridge reads ../../config etc. relative to dist: keep the tree.
          mkdir -p $out/lib/agentdeck
          cp -r package.json node_modules config shared hooks bridge $out/lib/agentdeck/
          mkdir -p $out/lib/agentdeck/services
          cp -r services/dot-relay $out/lib/agentdeck/services/
          rm -rf $out/lib/agentdeck/bridge/src $out/lib/agentdeck/bridge/dist/__tests__
          makeWrapper ${lib.getExe nodejs} $out/bin/agentdeck \
            --add-flags $out/lib/agentdeck/bridge/dist/cli.js
          runHook postInstall
        '';

        # Prebuilt addons (sharp's libvips, resvg, serialport) need only glibc
        # and libstdc++, which node has loaded already. Patching or stripping
        # them breaks sharp (segfault on require).
        dontPatchELF = true;
        dontStrip = true;
        meta.mainProgram = "agentdeck";
      });

      whisperModel = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
        sha256 = "0p8yqkwvpl9lyy43yajk305bps0v5z1qgyg0jwh35j7cb1nqs4y6";
      };
      voiceSettings = builtins.toJSON {
        transcriber = "whisper-cpp";
        locale = "en";
        whisperCli = lib.getExe' pkgs.whisper-cpp "whisper-cli";
        inherit whisperModel;
      };
      # settings.json is the daemon's own file; only its `voice` block is ours.
      syncSettings = pkgs.writeShellScript "agentdeck-voice-settings" ''
        set -eu
        f="$HOME/.agentdeck/settings.json"
        mkdir -p "$HOME/.agentdeck"
        [ -s "$f" ] || echo '{}' > "$f"
        tmp=$(mktemp "$f.XXXXXX")
        ${lib.getExe pkgs.jq} --argjson v '${voiceSettings}' '.voice = ((.voice // {}) + $v)' "$f" > "$tmp"
        mv "$tmp" "$f"
      '';
    in
    lib.mkIf config.dotfiles.programs.agentDeck.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        home.packages = [ agentdeck pkgs.tmux pkgs.playerctl ];

        systemd.user.services.agentdeck = {
          Unit = {
            Description = "AgentDeck daemon";
            Documentation = "https://github.com/Ilosariph/AgentDeck";
          };
          Service = {
            ExecStartPre = "${syncSettings}";
            ExecStart = "${lib.getExe agentdeck} daemon start --foreground";
            Restart = "on-failure";
            # tmux (voice + permission answers), ps (session discovery),
            # playerctl + busctl (MEDIA page: MPRIS players, speed), user tools.
            Environment = [
              "PATH=${lib.makeBinPath [ pkgs.tmux pkgs.procps pkgs.coreutils pkgs.playerctl pkgs.systemd ]}:/etc/profiles/per-user/${config.dotfiles.user.name}/bin:/run/current-system/sw/bin"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      # Boards on Wi-Fi reach the daemon (pairing token required on the LAN).
      networking.firewall.allowedTCPPorts = [ 9120 ];

      # Serial access to the boards for the logged-in user; keep ModemManager
      # off them: Espressif USB, CH340/CH343, CP210x, FTDI.
      services.udev.extraRules = lib.concatMapStrings (vid: ''
        SUBSYSTEM=="tty", ATTRS{idVendor}=="${vid}", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
      '') [ "303a" "1a86" "10c4" "0403" ];
    };
}

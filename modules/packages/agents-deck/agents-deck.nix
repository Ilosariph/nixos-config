{ inputs, ... }: {
  # agents deck: status board for Claude Code / Codex agents
  # (https://github.com/brushknight/agents-deck). Only the host side is packaged:
  # `agentctl` plus its systemd user service (`agentctl serve`); the web dashboard
  # at http://127.0.0.1:7340 replaces the Flutter tray app. Board firmware is
  # flashed separately (see ~/Projects/agents-deck).
  #
  # Built from the own fork (flake input `agents-deck`, branch waveshare-349-voice):
  # PR #23's Waveshare ESP32-S3-Touch-LCD-3.49 board plus V2 fixes and push-to-talk.
  # After pushing to it: `nix flake update agents-deck`.
  #
  # Push-to-talk: hold BOOT on an agent's card; whisper.cpp (small.en, on the CPU)
  # transcribes it locally and agentctl types it into the agent's prompt.
  #
  # The unit keeps agentctl's own name (agents-deck.service), so `agentctl status`
  # recognises it. Don't run `agentctl install`: home-manager owns the unit.
  # Pair a board once with `agentctl link add /dev/ttyACM*`.
  flake.nixosModules.agents-deck = { config, lib, pkgs, ... }:
    let
      agentctl = pkgs.buildGoModule rec {
        pname = "agentctl";
        version = "0-unstable-${inputs.agents-deck.shortRev}";
        src = inputs.agents-deck;
        modRoot = "backend";
        subPackages = [ "cmd/agentctl" ];
        vendorHash = "sha256-JzjbsYvIP4xKi4c0eWduAauYNaYtfalVb2w7LQthpYU=";
        # Hardcoded macOS paths: agents start in `/bin/zsh -lc`, live sessions are
        # found with /bin/ps and /usr/sbin/lsof. None exist on NixOS.
        postPatch = ''
          find backend -name '*.go' -exec sed -i \
            -e 's|"/bin/zsh"|"${pkgs.bashInteractive}/bin/bash"|g' \
            -e 's|"/bin/ps"|"${pkgs.procps}/bin/ps"|g' \
            -e 's|"/usr/sbin/lsof"|"${pkgs.lsof}/bin/lsof"|g' {} +
          # tmux falls back to a bare "tmux", which syscall.Exec (attach) can't resolve.
          substituteInPlace backend/internal/tmux/run_unix.go \
            --replace-fail 'return "tmux"' 'return "${pkgs.tmux}/bin/tmux"'
        '';
        ldflags = [ "-s" "-w" "-X main.version=${version}" ];
        # Tests start daemons, tmux and serial fakes; not worth it in the sandbox.
        doCheck = false;
        meta.mainProgram = "agentctl";
      };
      whisperModel = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
        sha256 = "0p8yqkwvpl9lyy43yajk305bps0v5z1qgyg0jwh35j7cb1nqs4y6";
      };
    in
    lib.mkIf config.dotfiles.programs.agentsDeck.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        home.packages = [ agentctl pkgs.tmux ];

        systemd.user.services.agents-deck = {
          Unit = {
            Description = "agents deck service (agentctl serve)";
            Documentation = "https://github.com/brushknight/agents-deck";
          };
          Service = {
            ExecStart = "${lib.getExe agentctl} serve";
            Restart = "on-failure";
            # Agents it starts run in tmux with the user's tools (claude, git, …).
            Environment = [
              "PATH=%h/.local/bin:${lib.makeBinPath [ pkgs.tmux ]}:/etc/profiles/per-user/${config.dotfiles.user.name}/bin:/run/current-system/sw/bin"
              "AGENTS_DECK_WHISPER=${lib.getExe' pkgs.whisper-cpp "whisper-cli"}"
              "AGENTS_DECK_WHISPER_MODEL=${whisperModel}"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      # Boards on Wi-Fi reach the deck's device listener (TLS 1.3, client
      # certificates from agentctl's own CA only).
      networking.firewall.allowedTCPPorts = [ 7341 ];

      # Serial access to the boards for the logged-in user, and keep ModemManager
      # from probing them (packaging/linux/70-agents-deck.rules): Espressif USB,
      # CH340/CH343, CP210x, FTDI.
      services.udev.extraRules = lib.concatMapStrings (vid: ''
        SUBSYSTEM=="tty", ATTRS{idVendor}=="${vid}", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
      '') [ "303a" "1a86" "10c4" "0403" ];
    };
}

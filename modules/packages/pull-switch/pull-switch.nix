{ ... }: {
  # Pull a branch of a flake repo, build this host's config on the host itself and
  # activate it. For trying configs from the MacBook (aarch64, deploy-rs would
  # cross-build) or a phone: any SSH client works.
  #
  #   ssh evo pull-switch                 # main, switch
  #   ssh evo pull-switch feat/foo        # other branch
  #   ssh evo pull-switch -a test feat/x  # activate without boot entry (reboot reverts)
  #   ssh evo pull-switch -s              # status + last log
  #
  # The wrapper only queues pull-switch.service and follows its journal, so the
  # build/switch keeps running if SSH drops (Ctrl-C detaches too).
  #
  # Self-check: the new generation must still contain pull-switch, else the switch is
  # refused (-f overrides). After activating, pull-switch.service must be loaded and
  # sshd (if it was running) active again, else it rolls back to the previous system.
  #
  # Secrets (sops): nix-secrets-deploy-key (cfg.deployKeySecret), read-only GitHub
  # deploy key for the private git+ssh nix-secrets input (shared with nix-eval).
  flake.nixosModules.pull-switch = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.pullSwitch;
      unit = "pull-switch.service";
      requestFile = "/run/pull-switch/request";
      doneFile = "/run/pull-switch/done";

      pull-switch = pkgs.writeShellApplication {
        name = "pull-switch";
        runtimeInputs = [ pkgs.coreutils pkgs.systemd ];
        text = ''
          usage() {
            cat <<EOF
          usage: pull-switch [-r repo] [-H host] [-a switch|test|boot] [-f] [branch]
                 pull-switch -s    status + last log
            branch  default ${cfg.branch}
            -r      flake repo URL, default ${cfg.repo}
            -H      nixosConfigurations.<host>, default ${cfg.host}
            -a      switch-to-configuration action, default switch
            -f      skip self-check / rollback
          EOF
          }

          if [ "$(id -u)" -ne 0 ]; then
            exec sudo /run/current-system/sw/bin/pull-switch "$@"
          fi

          repo=${lib.escapeShellArg cfg.repo}
          host=${lib.escapeShellArg cfg.host}
          action=switch
          force=0
          while getopts "r:H:a:fsh" opt; do
            case "$opt" in
              r) repo=$OPTARG ;;
              H) host=$OPTARG ;;
              a) action=$OPTARG ;;
              f) force=1 ;;
              s)
                systemctl status ${unit} --no-pager || true
                journalctl -u ${unit} -o cat -n 100 --no-pager
                exit 0 ;;
              *) usage; exit 2 ;;
            esac
          done
          shift $((OPTIND - 1))
          branch=''${1:-${lib.escapeShellArg cfg.branch}}

          case "$action" in switch|test|boot) ;; *) usage; exit 2 ;; esac
          # Values go into an EnvironmentFile: no whitespace/quotes.
          re='^[A-Za-z0-9._/@:+=~%?&,-]+$'
          for v in "$repo" "$host" "$branch"; do
            if ! [[ "$v" =~ $re ]]; then
              echo "invalid argument: $v" >&2; exit 2
            fi
          done

          if [ "$(systemctl show -p ActiveState --value ${unit})" = activating ]; then
            echo "pull-switch already running; pull-switch -s for its log" >&2
            exit 1
          fi

          install -d -m 0700 /run/pull-switch
          token="$(date +%s%N)-$$"
          rm -f ${doneFile}
          printf 'PULL_SWITCH_REPO=%s\nPULL_SWITCH_BRANCH=%s\nPULL_SWITCH_HOST=%s\nPULL_SWITCH_ACTION=%s\nPULL_SWITCH_FORCE=%s\nPULL_SWITCH_TOKEN=%s\n' \
            "$repo" "$branch" "$host" "$action" "$force" "$token" > ${requestFile}

          since=$(date '+%Y-%m-%d %H:%M:%S')
          systemctl reset-failed ${unit} 2>/dev/null || true
          systemctl start --no-block ${unit}

          journalctl -u ${unit} -o cat -f --since "$since" &
          jpid=$!
          trap 'kill "$jpid" 2>/dev/null; echo; echo "detached, pull-switch keeps running (pull-switch -s)"; exit 130' INT

          # Poll instead of a blocking `systemctl start`: the switch reloads/re-execs
          # systemd, which drops the D-Bus connection a blocking start waits on.
          # Completion comes from ExecStopPost's done file, not unit properties: a
          # finished oneshot can be unloaded, which blanks InvocationID/Result.
          result=
          while :; do
            sleep 2
            if [ -f ${doneFile} ]; then
              tok=''' res='''
              read -r tok res < ${doneFile} || true
              if [ "$tok" = "$token" ]; then result=$res; break; fi
            fi
            state=$(systemctl show -p ActiveState --value ${unit} 2>/dev/null || true)
            # Empty = systemd busy (reload/re-exec during the switch): keep waiting.
            case "$state" in ""|activating|deactivating) continue ;; esac
            # Not running, no done file, no queued job: start never ran (e.g. a failed dependency).
            if [ -z "$(systemctl list-jobs --no-legend ${unit} 2>/dev/null)" ] && ! [ -f ${doneFile} ]; then
              result="not-started($state)"; break
            fi
          done
          sleep 1
          kill "$jpid" 2>/dev/null || true

          echo "pull-switch: $result"
          [ "$result" = success ]
        '';
      };
    in
    lib.mkIf cfg.enable {
      environment.systemPackages = [ pull-switch ];

      security.sudo.extraRules = [{
        users = [ config.dotfiles.user.name ];
        commands = [
          { command = "/run/current-system/sw/bin/pull-switch *"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/pull-switch"; options = [ "NOPASSWD" ]; }
        ];
      }];

      sops.secrets = lib.mkIf (cfg.deployKeySecret != null) {
        ${cfg.deployKeySecret}.mode = "0400";
      };

      # Pin GitHub's host key so the non-interactive fetch never hits a TOFU prompt.
      programs.ssh.knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

      systemd.tmpfiles.rules = [
        "d /var/lib/pull-switch 0700 root root -"
        "d /run/pull-switch 0700 root root -"
      ];

      systemd.services.pull-switch = {
        description = "Pull, build and activate a nixos-config branch";
        # Never touched by switch-to-configuration: it runs inside this unit.
        restartIfChanged = false;
        stopIfChanged = false;
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = [ config.nix.package pkgs.git pkgs.openssh pkgs.coreutils config.systemd.package ];
        environment = {
          HOME = "/root";
        } // lib.optionalAttrs (cfg.deployKeySecret != null) {
          GIT_SSH_COMMAND = "ssh -i ${config.sops.secrets.${cfg.deployKeySecret}.path} -o IdentitiesOnly=yes -o BatchMode=yes";
        };
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = "-${requestFile}";
          TimeoutStartSec = "3h";
          # Runs on success and failure; tells the waiting wrapper this request is done.
          # Request file removed only here: systemd re-reads EnvironmentFile per Exec*.
          ExecStopPost = "${pkgs.writeShellScript "pull-switch-done" ''
            echo "''${PULL_SWITCH_TOKEN:-none} $SERVICE_RESULT" > ${doneFile}
            rm -f ${requestFile}
          ''}";
        };
        script = ''
          set -euo pipefail
          repo=''${PULL_SWITCH_REPO:-${lib.escapeShellArg cfg.repo}}
          branch=''${PULL_SWITCH_BRANCH:-${lib.escapeShellArg cfg.branch}}
          host=''${PULL_SWITCH_HOST:-${lib.escapeShellArg cfg.host}}
          action=''${PULL_SWITCH_ACTION:-switch}
          force=''${PULL_SWITCH_FORCE:-0}

          case "$repo" in *\?*) url="$repo&ref=$branch" ;; *) url="$repo?ref=$branch" ;; esac
          profile=/nix/var/nix/profiles/system
          prev=$(readlink -f /run/current-system)

          echo "==> building $url#$host"
          out=$(nix build --refresh --print-out-paths \
            --out-link /var/lib/pull-switch/result \
            "$url#nixosConfigurations.\"$host\".config.system.build.toplevel")
          echo "==> built $out"

          if [ "$out" = "$prev" ]; then
            echo "==> already running this configuration"
            exit 0
          fi

          if [ ! -e "$out/etc/systemd/system/${unit}" ] || [ ! -x "$out/sw/bin/pull-switch" ]; then
            if [ "$force" != 1 ]; then
              echo "!! new configuration has no pull-switch: refusing (rerun with -f to switch anyway)"
              exit 1
            fi
            echo "!! new configuration has no pull-switch, continuing (-f)"
          fi

          sshd_was_active=0
          systemctl is-active --quiet sshd.service && sshd_was_active=1

          echo "==> $action"
          if [ "$action" != test ]; then
            nix-env -p "$profile" --set "$out"
          fi
          rc=0
          "$out/bin/switch-to-configuration" "$action" || rc=$?
          [ "$rc" -ne 0 ] && echo "!! switch-to-configuration exited $rc"

          [ "$action" = boot ] && { echo "==> done, active after reboot"; exit "$rc"; }
          [ "$force" = 1 ] && { echo "==> done (-f, no self-check)"; exit "$rc"; }

          ok=1
          if [ "$(readlink -f /run/current-system)" != "$out" ]; then
            echo "!! /run/current-system is not the new configuration"; ok=0
          fi
          if ! systemctl cat ${unit} >/dev/null 2>&1; then
            echo "!! ${unit} not loaded after switch"; ok=0
          fi
          if [ "$sshd_was_active" = 1 ] && ! systemctl is-active --quiet sshd.service; then
            echo "!! sshd not active after switch"; ok=0
          fi

          if [ "$ok" = 1 ]; then
            echo "==> self-check ok"
            exit "$rc"
          fi

          echo "==> rolling back to $prev"
          if [ "$action" != test ]; then
            nix-env -p "$profile" --set "$prev"
          fi
          "$prev/bin/switch-to-configuration" "$action" || true
          exit 1
        '';
      };
    };
}

{ ... }: {
  # `wol <host>` sends a magic packet to a host from dotfiles.private.macs and
  # waits until it answers ping. Any unique prefix works (`wol nuc`).
  flake.nixosModules.wol = { config, lib, pkgs, ... }:
    let
      macs = config.dotfiles.private.macs or { };
      ips = config.dotfiles.private.hosts or { };
      line = name: "${name} ${macs.${name}} ${ips.${name} or "-"}";
      table = pkgs.writeText "wol-hosts" (lib.concatMapStringsSep "\n" line (lib.attrNames macs) + "\n");

      wol = pkgs.writeShellApplication {
        name = "wol";
        runtimeInputs = [ pkgs.wakeonlan pkgs.iputils pkgs.coreutils ];
        text = ''
          if [ $# -ne 1 ]; then
            echo "usage: wol <host>   (hosts: $(cut -d' ' -f1 ${table} | tr '\n' ' '))" >&2
            exit 2
          fi
          matches=()
          while read -r name mac ip; do
            [ "$name" = "$1" ] && { matches=("$name $mac $ip"); break; }
            case "$name" in "$1"*) matches+=("$name $mac $ip") ;; esac
          done < ${table}
          if [ ''${#matches[@]} -ne 1 ]; then
            echo "wol: '$1' matches ''${#matches[@]} hosts (hosts: $(cut -d' ' -f1 ${table} | tr '\n' ' '))" >&2
            exit 2
          fi
          read -r name mac ip <<< "''${matches[0]}"

          wakeonlan "$mac" >/dev/null
          echo "wol: magic packet sent to $name ($mac)"
          [ "$ip" = - ] && exit 0
          echo -n "wol: waiting for $ip "
          for _ in $(seq 60); do
            if ping -c 1 -W 3 "$ip" >/dev/null 2>&1; then echo " up"; exit 0; fi
            echo -n .
          done
          echo " no reply after ~3 min"
          exit 1
        '';
      };
    in
    lib.mkIf config.dotfiles.programs.wol.enable {
      environment.systemPackages = [ wol ];
    };
}

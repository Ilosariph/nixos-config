{ lib, config, pkgs, ... }:

lib.mkIf config.dotfiles.vpn {
  system.activationScripts.importWireguardVPNS = {
    deps = [ "etc" ];
    text = ''
			NMCLI=${pkgs.networkmanager}/bin/nmcli

			import_vpn() {
				NAME="$1"
				FILE="/etc/wireguard/$1.conf"

				if [ -f "$FILE" ]; then
					echo "Importing $NAME from $FILE"
					$NMCLI connection delete "$NAME" >/dev/null 2>&1 || true
					$NMCLI connection import type wireguard file "$FILE"
					$NMCLI connection modify "$NAME" connection.autoconnect no
					$NMCLI connection down $NAME
					echo "Autoconnect disabled for $NAME"
				else
					echo "Skipping $NAME (no config found at $FILE)"
				fi
			}

			import_vpn home
			import_vpn proton
    '';
  };
}

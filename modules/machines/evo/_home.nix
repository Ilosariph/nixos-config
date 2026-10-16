{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      python312

      htop
      unzip
      rocmPackages.rocm-smi

      lm_sensors
      amdgpu_top

      ollama
      claude-code

      # Plex/Jellyfin/Emby client. Server login (Jellyfin at http://localhost:8096)
      # is done in-app — connections + auth tokens live in its DB, not config.
      plezy
    ];
  };
}

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
    ];
  };
}

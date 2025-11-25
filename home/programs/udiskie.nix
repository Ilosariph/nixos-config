{ pkgs, ... }:
{
  services.udiskie = {
    enable = true;
    settings = {
      program_options = {
        file_manager = "${pkgs.kitty}/bin/kitty ${pkgs.yazi}/bin/yazi";
      };
    };
  };
}

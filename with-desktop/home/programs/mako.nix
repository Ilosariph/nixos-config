{ ... }:
{
  services.mako = {
    enable = true;

    settings = {
      font = "JetBrainsMono Nerd Font 12";
      background-color = "#1a1b26";
      text-color = "#a9b1d6";
      border-color = "#3b4261";
      border-radius = 8;
      border-size = 1;
      padding = "12,16";
      margin = "10";
      width = 360;
      max-visible = 5;
      sort = "-time";
      layer = "overlay";
      anchor = "top-right";
      default-timeout = 5000;

      "urgency=low" = {
        border-color = "#3b4261";
        default-timeout = 3000;
      };

      "urgency=normal" = {
        border-color = "#3b4261";
        default-timeout = 5000;
      };

      "urgency=high" = {
        border-color = "#f7768e";
        text-color = "#f7768e";
        default-timeout = 0;
      };
    };
  };
}

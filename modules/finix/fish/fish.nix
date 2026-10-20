{ ... }: {
  # home-manager programs.fish/starship/fzf → system fish + hjem-managed files
  flake.finixModules.fish = { config, lib, pkgs, modules, ... }:
    let
      toml = pkgs.formats.toml { };
      starshipSettings = {
        add_newline = false;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        package.disabled = true;
        directory = {
          truncation_length = 3;
          style = "bold cyan";
        };
      };
    in {
      imports = [ modules.fish ];

      config = lib.mkIf config.dotfiles.programs.fish.enable {
        programs.fish.enable = true;
        environment.systemPackages = with pkgs; [ starship fzf ];

        hjem.users.${config.dotfiles.user.name}.xdg.config.files = {
          "starship.toml".source = toml.generate "starship.toml" starshipSettings;
          "fish/conf.d/dotfiles.fish".text = ''
            if status is-interactive
              ${pkgs.starship}/bin/starship init fish | source
              ${pkgs.fzf}/bin/fzf --fish | source
            end
          '';
        };
      };
    };
}

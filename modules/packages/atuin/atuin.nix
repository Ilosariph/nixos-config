{ ... }: {
  flake.nixosModules.atuin = { config, lib, ... }:
    let
      cfg = config.dotfiles.programs.atuin;
    in
    lib.mkIf cfg.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.atuin = {
          enable = true;

          enableBashIntegration = config.dotfiles.programs.bash.enable;
          enableFishIntegration = config.dotfiles.programs.fish.enable;

          # Atuin owns Ctrl-R; the up arrow keeps fish's prefix search.
          # fzf binds Ctrl-R too, but its fish init is ordered before atuin's,
          # so atuin wins the binding while fzf keeps Ctrl-T and Alt-C.
          flags = [ "--disable-up-arrow" ];

          # Atuin rewrites config.toml after every command, so let the
          # generated file win instead of leaving a stale copy behind.
          forceOverwriteSettings = true;

          # The daemon buffers history writes and syncs in the background;
          # only useful once a sync server is configured.
          daemon.enable = cfg.sync.enable;

          settings = {
            auto_sync = cfg.sync.enable;
            sync_address = cfg.sync.address;
            sync_frequency = cfg.sync.frequency;

            # Updates come from nixpkgs, not from atuin itself.
            update_check = false;

            search_mode = "fuzzy";
            filter_mode = "global";
            # Ctrl-R cycles a workspace filter when inside a git repo.
            workspaces = true;

            style = "compact";
            inline_height = 25;
            show_preview = true;
            # Enter puts the command on the prompt line instead of running it.
            enter_accept = false;

            # Day-first date parsing ("15/09", "yesterday 15:00").
            dialect = "uk";
            secrets_filter = true;
          };
        };
      };
    };
}

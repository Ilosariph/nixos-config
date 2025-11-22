{ config, ... }:
{
  programs.yazi.enable = true;
  programs.yazi.keymap = {
	mgr.prepend_keymap = [
	  {
	  run = [
        # The shell command uses a multi-line string (''...) for easy internal quoting
        ''shell -- for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list''
        "yank"
      ];
	    on = "y";
	  }
	  # { run = [ "'shell -- for path in \"$@\"; do echo \"file://$path\"; done | wl-copy -t text/uri-list'" "yank" ]; on = [ "y" ]; }
	];
  };
  programs.yazi.settings = {
	preview = {
	  cache_dir = "${config.xdg.cacheHome}/yazi/preview-cache";
	  max_width = 1920;
	};
	tasks = {
	  image_bound = [0 0];
	};
  };
}

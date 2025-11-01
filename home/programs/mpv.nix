{
  programs.mpv = {
	enable = true;
	config = {
	  window-maximized = true;
	  screenshot-dir = "~/Documents/enc";
	  script-opts-add = "osc-visibility=always";
	  keep-open = true;
	  screenshot-template = "mpv-shot-%tY-%tm-%td-%tHh%tMm%tSs-%f";
	  mute = false;
	};
	bindings = {
	  # SPACE = "script-message pause-replay";
	  "e" = "screenshot";
	  "o" = "keypress CLOSE_WIN";
	};
  };
}

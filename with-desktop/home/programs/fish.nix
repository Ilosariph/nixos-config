{
	programs.starship = {
		enable = true;
		enableFishIntegration = true;

		settings = {
			add_newline = false;
			character = {
				success_symbol = "[➜](bold green)";
				error_symbol = "[➜](bold red)";
			};
			git_branch = {
				symbol = " ";
				style = "bold purple";
			};
			package.disabled = true;
			directory = {
				truncation_length = 3;
				style = "bold cyan";
			};
		};
	};
	programs.fish.enable = true;
}

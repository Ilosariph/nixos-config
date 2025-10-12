.PHONY: update
update:
	home-manager switch --flake .#simon

.PHONY: clean
clean:
	nix-collect-garbage -d

{
  description = "Configs for niri/umbriel and server stuff";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Temporary pin for musescore: broken in current nixos-unstable
    # (makeCWrapper: Unknown argument --prefix LD_LIBRARY_PATH). Remove
    # once fixed upstream.
    nixpkgs-musescore.url = "github:nixos/nixpkgs/da5ad661ba4e5ef59ba743f0d112cbc30e474f32";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-xr = {
      url = "github:nix-community/nixpkgs-xr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private repo holding the sops-encrypted secrets (hosts/<host>.yaml,
    # shared.yaml, .sops.yaml) and eval-time private.nix.
    # Fetched over SSH with the user's own key/agent, so no GitHub PAT in
    # nix.conf. Pull new secrets with ./secrets.sh update. See docs/secrets.md.
    nix-secrets = {
      url = "git+ssh://git@github.com/Ilosariph/nix-secrets.git?ref=main&shallow=1";
      flake = false;
    };

    # TODO: noctalia v5 dropped the keybind-cheatsheet plugin; Mod+Slash bind
    # is commented out in niri.nix. Re-enable once a v5 cheatsheet plugin ships.
    noctalia-shell = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Asahi kernel branch carrying the experimental DisplayPort-over-USB-C
    # support. Consumed by modules/machines/macbook/kernel.nix, which builds it
    # in place of the released linux-asahi.
    linux-asahi-fairydust = {
      url = "github:AsahiLinux/linux/fairydust";
      flake = false;
    };

    # Aurora (Omarchy M) Apple Silicon stack: kernel, aura (m1n1 fork), Touch
    # ID userspace. Used as plain files (overlay subset + two modules) by
    # modules/machines/macbook/aurora.nix, so its own nixpkgs/apple-silicon
    # pins and flake inputs are not pulled in.
    nixos-aurora = {
      url = "github:aurora-silicon/nixos-aurora/channel-testing";
      flake = false;
    };

    # Fork of tiny-dfr adding configurable multi-layer touch bar buttons
    # (Exec/SwitchLayer/CycleLayer actions, named layers).
    # https://github.com/Ilosariph/dfrd
    dfrd = {
      url = "github:Ilosariph/dfrd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative partitioning (vps, installed via nixos-anywhere).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative neovim config (modules/packages/neovim/neovim.nix).
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yeetmouse.url = "github:AndyFilter/YeetMouse?dir=nix";

    # Motorized fader controller host: NixOS module running it as a user
    # service. https://github.com/Ilosariph/motorized-faders
    motorized-faders = {
      url = "github:Ilosariph/motorized-faders";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private (not secret) config: own tools, later work stuff. Also checked
    # out as the ./nix-private submodule for editing; build against that
    # checkout with ./build.sh --local-private. Imported on mainpc + macbook (tools),
    # evo (nixosModules.evo: vid-finder search service), nucserver (nixosModules.nucserver).
    nix-private = {
      url = "git+ssh://git@github.com/Ilosariph/nix-private.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Expose options.nix as a shared nixosModule picked up by all hosts
        { flake.nixosModules.options = ./options.nix; }
        # Auto-discover all aspect modules under modules/packages/
        (inputs.import-tree ./modules/packages)
        # Auto-discover all host instantiations (passed directly, bypassing _ skip)
        (inputs.import-tree ./modules/hosts)
      ];
      systems = [ "x86_64-linux" "aarch64-linux" ];
    };
}

{ config, pkgs, ... }:
# ComfyUI on evo (GMKtec EVO-X2 — Ryzen AI Max+ 395 / Strix Halo, Radeon 8060S, gfx1151).
#
# Uses the comfyui-nix fork pinned to the gfx1151 branch. The stock ROCm wheels
# target gfx1100 and SEGV on this iGPU, so rocmArch = "gfx1151" selects the
# comfy-ui-rocm-gfx1151 package, which bakes HSA_OVERRIDE_GFX_VERSION plus the
# GPU_MAX_HEAP_SIZE / GPU_MAX_ALLOC_PERCENT tuning into the launcher.
#
# The upstream module (imported in modules/hosts/evo.nix, where `inputs` is in
# scope) brings its own overlay, which provides comfy-ui-rocm-gfx1151.
#
# VRAM note: llama-swap keeps Qwen3.6-27B resident on the same iGPU. Gemma4-26B
# unloads after 30 min idle (ollama.nix) to free VRAM for image generation.
#
# nixpkgs ships its own services.comfyui module; disable it so the flake's
# module (which has the rocmArch option) owns the option tree.
let
  # The `p` share is mounted at /mnt/projects (dotfiles.shares in options.nix) and
  # holds the model collection from the old stable-diffusion-webui install.
  sdWebui = "/mnt/projects/stable-diffusion-webui";

  # a1111 uses different folder names than ComfyUI, so the paths are remapped
  # rather than pointed at as-is. Paths are relative to `base_path`.
  #
  # Read-only by design: the service leaves its own writable model dirs under
  # dataDir in place (ComfyUI merges extra paths with the built-in ones), so
  # anything downloaded later lands on local disk, not on the CIFS share.
  extraModelPaths = pkgs.writeText "comfyui-extra-model-paths.yaml" ''
    stable-diffusion-webui:
      base_path: ${sdWebui}
      checkpoints: models/Stable-diffusion
      loras: models/Lora
      vae: models/VAE
      vae_approx: models/VAE-approx
      embeddings: embeddings
      hypernetworks: models/hypernetworks
      # ControlNet/ mixes actual controlnets with CLIP-vision and IP-Adapter
      # models. Pointing both loaders at the same folder lets each list the
      # files it understands (ComfyUI filters by file extension, not by name).
      # IP-Adapter is deliberately not mapped: its `ipadapter` folder key only
      # exists once a custom node registers it, and an unregistered key is
      # created with an empty extension set, which lists nothing.
      controlnet: models/ControlNet
      clip_vision: models/ControlNet
      # ComfyUI has one upscaler dir; a1111 splits ESRGAN/RealESRGAN.
      # GFPGAN/Codeformer are face restoration, not upscalers — a1111 ran them
      # as a built-in post-process, and core ComfyUI has no equivalent loader,
      # so they are left out.
      upscale_models: |
        models/ESRGAN
        models/RealESRGAN
  '';
in
{
  disabledModules = [ "services/misc/comfyui.nix" ];

  services.comfyui = {
    enable = true;
    gpuSupport = "rocm";
    rocmArch = "gfx1151";
    # Stays on loopback. ComfyUI has no authentication of its own, so the LAN
    # reaches it only through the authenticated nginx proxy below.
    listenAddress = "127.0.0.1";
    port = 8188;
    dataDir = "/var/lib/comfyui";
    # /mnt/projects is an x-systemd.automount CIFS mount, so the unit to depend on
    # is the .automount, not the .mount — the latter only exists once triggered.
    # Without this, a boot-time start can scan the models dir before the share is
    # reachable and come up with an empty checkpoint list.
    requiresMounts = [ "mnt-projects.automount" ];
    extraArgs = [
      "--extra-model-paths-config"
      "${extraModelPaths}"
    ];
  };

  # htpasswd file for the proxy. Generate the entry with:
  #   nix run nixpkgs#apacheHttpd -- htpasswd -nbB simon '<password>'
  # and store the resulting "simon:$2y$..." line as comfyui-htpasswd in
  # secrets/secrets.yaml.
  sops.secrets.comfyui-htpasswd = {
    owner = "nginx";
    group = "nginx";
    mode = "0400";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."comfyui" = {
      default = true;
      listen = [
        {
          addr = "0.0.0.0";
          port = 8189;
        }
      ];
      basicAuthFile = config.sops.secrets.comfyui-htpasswd.path;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8188";
        # ComfyUI streams progress over a websocket; without an upgrade the UI
        # connects but never shows queue or preview updates.
        proxyWebsockets = true;
        extraConfig = ''
          # Model and image uploads are large; the 1M default rejects them.
          client_max_body_size 0;
          # Generations can run for minutes with no bytes on the wire.
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
  };

  # Only the authenticated proxy port is exposed; 8188 stays loopback-only.
  networking.firewall.allowedTCPPorts = [ 8189 ];
}

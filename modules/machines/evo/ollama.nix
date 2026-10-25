{ pkgs, config, ... }:
# Local LLM inference on evo (Radeon 8060S / Strix Halo, gfx1151, RDNA 3.5).
#
# Backend: llama.cpp built with the Vulkan (RADV) backend — ~40% faster than Ollama-ROCm
# on this iGPU at standard context. A single llama-swap proxy on 127.0.0.1:8081 fronts
# both models (one OpenAI-compatible endpoint, /v1/models lists both):
#   - Qwen3.8-27B   ttl 0    always resident (Hermes default / coding model)
#   - Gemma4-26B    ttl 1800 loads on demand, unloads after 30 min idle (frees VRAM for
#                            image-gen). llama-swap spawns/kills the llama-server per model.
#
# GGUF weights are fetched declaratively (pinned commit + hash) into the nix store.
let
  llamaVulkan = pkgs.llama-cpp.override { vulkanSupport = true; };

  qwenGguf = pkgs.fetchurl {
    name = "qwen3.8-27b-q4km.gguf";
    url = "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_M.gguf";
    hash = "sha256-Mi4ZT/eXQce6pJfCQPZ39UsgGw76tEyo5Q8SKzkSNII=";
  };

  gemmaGguf = pkgs.fetchurl {
    name = "gemma-4-26b-a4b-it-q4km.gguf";
    url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/resolve/c099eb48e663fd284577b04978a94ffccb261841/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf";
    hash = "sha256-8sKLPcR3aTGsb4eeEfID3sY36g8UJnqG7I9hZfY/KT8=";
  };

  # Shared llama-server flags for both models.
  llamaFlags = "--n-gpu-layers 999 --ctx-size 262144 --flash-attn on";

  # llama-swap: one OpenAI-compatible endpoint (:8081) fronting per-model llama-server
  # processes. It lists every model at /v1/models — so both show up in the Hermes picker
  # and open-webui — and load/unloads them on demand via per-model `ttl`:
  #   - qwen3.8-27b : ttl 0  -> never unloaded, always resident (Hermes default/coding)
  #   - gemma4-26b  : ttl 1800 -> unloads after 30 min idle, freeing VRAM for image-gen
  # ${PORT} is auto-assigned by llama-swap and injected into each cmd.
  swapConfig = pkgs.writeText "llama-swap.yaml" ''
    models:
      "qwen3.8-27b":
        cmd: >
          ${llamaVulkan}/bin/llama-server --port ''${PORT}
          --model ${qwenGguf} ${llamaFlags} --alias qwen3.8-27b
        ttl: 0
      "gemma4-26b":
        cmd: >
          ${llamaVulkan}/bin/llama-server --port ''${PORT}
          --model ${gemmaGguf} ${llamaFlags} --alias gemma4-26b
        ttl: 1800
  '';

  common = {
    Restart = "on-failure";
    RestartSec = 5;
    DynamicUser = true;
    # RADV needs read access to the render node.
    SupplementaryGroups = [ "render" "video" ];
  };
in
{
  # llama-swap proxy on :8081 — the single OpenAI endpoint for both models. Spawns the
  # per-model llama-server processes on demand (see swapConfig above for TTL policy).
  systemd.services.llama-swap = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "llama-swap (Qwen3.8-27B resident + Gemma4-26B on-demand) on :8081";
    serviceConfig = common // {
      ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config ${swapConfig} --listen 127.0.0.1:8081";
    };
  };

  # open-webui chat UI, pointed at the Qwen llama-server's OpenAI-compatible endpoint.
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
    environment = {
      # open-webui talks OpenAI protocol to llama-server.
      OPENAI_API_BASE_URL = "http://127.0.0.1:8081/v1";
      OPENAI_API_KEY = "none";
      # No Ollama backend anymore.
      ENABLE_OLLAMA_API = "false";
    };
  };

  # Vulkan ICD for the AMD iGPU (RADV via mesa). ROCm is no longer needed for inference
  # (kept elsewhere only for the ComfyUI direnv shell).
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [ mesa vulkan-loader ];

  environment.systemPackages = with pkgs; [ vulkan-tools ];

  # open-webui on 8080 is loopback-only; reached via tunnel/reverse proxy if needed.
  networking.firewall.allowedTCPPorts = [ 4001 ];
}

# ComfyUI devshell for AMD Ryzen AI Max 395 (gfx1151 / Strix Halo)
#
# Usage:
#   nix-shell shells/comfyui-rocm-gfx1151.nix
#
# First-time setup (run inside the shell):
#   git clone https://github.com/comfyanonymous/ComfyUI.git && cd ComfyUI
#   python -m venv venv && source venv/bin/activate
#   pip install torch torchvision torchaudio --index-url https://repo.amd.com/rocm/whl/gfx1151/
#   pip install -r requirements.txt
#   python main.py --lowvram
#
# Subsequent runs:
#   source ComfyUI/venv/bin/activate
#   python ComfyUI/main.py --lowvram

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; }, ... }:

let
  libraryPath = with pkgs; lib.makeLibraryPath [
    stdenv.cc.cc.lib
    glibc
    zlib
    rocmPackages.clr
    rocmPackages.rocblas
    rocmPackages.hipblas
    rocmPackages.miopen
  ];
in

pkgs.mkShell {
  buildInputs = with pkgs; [
    python312
    python312Packages.pip
    python312Packages.virtualenv
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    rocmPackages.clr
    git
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${libraryPath}:$LD_LIBRARY_PATH"

    # Ryzen AI Max 395 (gfx1151 / Strix Halo) ROCm settings
    unset CUDA_VISIBLE_DEVICES
    export HIP_VISIBLE_DEVICES=0
    export HSA_OVERRIDE_GFX_VERSION=11.5.1
    export GPU_MAX_HEAP_SIZE=100
    export GPU_MAX_ALLOC_PERCENT=100
    export AMD_LOG_LEVEL=0
    export FLASH_ATTENTION_TRITON_AMD_ENABLE=1

    echo ""
    echo "ComfyUI ROCm shell — Ryzen AI Max 395 (gfx1151)"
    echo "HSA_OVERRIDE_GFX_VERSION=$HSA_OVERRIDE_GFX_VERSION"
    echo ""
    echo "First-time setup:"
    echo "  git clone https://github.com/comfyanonymous/ComfyUI.git && cd ComfyUI"
    echo "  python -m venv venv && source venv/bin/activate"
    echo "  pip install torch torchvision torchaudio --index-url https://repo.amd.com/rocm/whl/gfx1151/"
    echo "  pip install -r requirements.txt"
    echo "  python main.py --lowvram"
  '';
}

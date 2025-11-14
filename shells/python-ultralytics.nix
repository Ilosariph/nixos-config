{ pkgs ? import <nixpkgs> {}, ... }:
let
  pythonEnv = pkgs.python312.withPackages (p: with p; [
    numpy
    opencv4
	ultralytics
  ]);

  libraryPath = with pkgs; lib.makeLibraryPath [
    stdenv.cc.cc.lib
    glibc
    zlib
    pkgs.libglvnd
    pkgs.mesa
    pkgs.xorg.libX11
    pkgs.glib
  ];
in
# `nix-shell`
# `echo $LD_LIBRARY_PATH`
# Edit runconfig in PyCharm
# Add output of echo to LD_LIBRARY_PATH variable
# If that doesn't work, create the venv in the nix-shell `python -m venv /path/to/.venv`:w
pkgs.mkShell {
  buildInputs = [
    pythonEnv
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${libraryPath}:$LD_LIBRARY_PATH"
  '';
}

{ pkgs ? import <nixpkgs> {}, ... }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    python312
    python312Packages.flask
    python312Packages.pillow
    python312Packages.piexif
  ];
}

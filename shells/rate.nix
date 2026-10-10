{ pkgs ? import <nixpkgs> {}, ... }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    python312
    python312Packages.flask
    python312Packages.flask-sqlalchemy
    python312Packages.sqlalchemy
    python312Packages.pillow
    python312Packages.imagehash
    python312Packages.numpy
    python312Packages.gunicorn
  ];
}

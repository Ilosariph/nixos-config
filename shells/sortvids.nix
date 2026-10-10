{ pkgs ? import <nixpkgs> {}, ... }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    python312
    python312Packages.flask
    python312Packages.gunicorn
    python312Packages.google-api-python-client
    python312Packages.yt-dlp
    python312Packages.python-dotenv
  ];
}

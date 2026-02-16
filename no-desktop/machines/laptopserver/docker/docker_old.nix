{ lib, pkgs, pkgs-stable, config, ... }:
{
 home.file."docker/project/docker-compose.yml" = {
    text = ''
      services:
        app:
          image: nginx:latest
          ports:
            - "8080:80"
    '';
    mutable = true;
  };
}

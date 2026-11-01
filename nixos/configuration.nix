{ lib, ... }:

{
  imports = [
    ./base.nix
    ./gce.nix
    ./extensions/caddy.nix
    ./extensions/opencode.nix
    ./extensions/browser-terminal.nix
    ./extensions/idle-shutdown.nix
  ];

  # The reference workstation enables the OpenCode web service and browser
  # terminal behind an HTTPS reverse proxy, plus idle shutdown.
  services.workstation = {
    caddy.enable = true;
    opencode.enable = true;
    browserTerminal.enable = true;
    idleShutdown.enable = true;
  };
}

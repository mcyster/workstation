{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.workstation.opencode;
in
{
  options.services.workstation.opencode = {
    enable = lib.mkEnableOption "OpenCode web service";

    package = lib.mkPackageOption pkgs "opencode" { };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/workstation/opencode.env";
      description = ''
        Environment file shared with the Caddy browser password, holding
        `OPENCODE_SERVER_USERNAME` and `OPENCODE_SERVER_PASSWORD`. Lives outside
        the Nix store and is rewritten by the `web-access` rotation.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/workstation/opencode-secrets.env";
      description = ''
        Environment file holding the OpenCode user secrets (for example
        `OPENROUTER_API_KEY` and `GH_TOKEN`), sourced into the server process.
        Lives outside the Nix store and is rewritten by the `secrets` action.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "developer";
      description = "User the OpenCode service runs as.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Interface the OpenCode server binds to. Keep on localhost behind the reverse proxy.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 10999;
      description = "Port the OpenCode server listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Expose the opencode CLI on the system PATH so developers can attach to
    # and use the same server from a terminal.
    environment.systemPackages = [ cfg.package ];

    # The server rejects anonymous access; the site stays closed until
    # `web-access` rotates in a shared password and restarts the service.
    # OpenCode always authenticates the user as `opencode` (the
    # OPENCODE_SERVER_USERNAME value is ignored by `serve`).
    systemd.tmpfiles.rules = [
      "d /var/lib/workstation 0750 root root -"
      "f ${cfg.environmentFile} 0600 root root - OPENCODE_SERVER_USERNAME=opencode\nOPENCODE_SERVER_PASSWORD=0trl0sXVVSLxHTkFwYkM"
      "f ${cfg.secretsFile} 0600 root root -"
    ];

    systemd.services.opencode = {
      description = "OpenCode web service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment.HOME = "/home/${cfg.user}";

      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";
        EnvironmentFile = [ cfg.environmentFile cfg.secretsFile ];
        ExecStart = "${lib.getExe cfg.package} serve --hostname ${cfg.host} --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}

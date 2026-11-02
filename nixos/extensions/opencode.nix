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
      "f ${cfg.environmentFile} 0600 root root - OPENCODE_SERVER_USERNAME=opencode\nOPENCODE_SERVER_PASSWORD=0trl0sXVVSLxHTkFwYkM"
    ];

    # The opencode secret (OPENROUTER_API_KEY, GH_TOKEN, ...) is loaded from
    # /var/lib/workstation/secrets/.env.opencode, which the `secrets` action
    # writes and restarts consumers of. The `-` prefix means the file is
    # loaded only when it exists.
    systemd.services.opencode = {
      description = "OpenCode web service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment.HOME = "/home/${cfg.user}";

      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";
        # The browser-auth file must come LAST: systemd lets later files win,
        # so `OPENCODE_SERVER_PASSWORD` from the opencode secret would
        # otherwise override the managed password. The secret file is loaded
        # only when it exists (the `-` prefix skips a missing file), so no
        # empty placeholder is generated.
        EnvironmentFile = [ "-/var/lib/workstation/secrets/.env.opencode" cfg.environmentFile ];
        ExecStart = "${lib.getExe cfg.package} serve --hostname ${cfg.host} --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}

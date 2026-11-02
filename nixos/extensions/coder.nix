{ config, lib, pkgs, ... }:

let
  cfg = config.services.workstation.coder;
in
{
  # Coder — VS Code in the browser (code-server), served under /coder behind
  # the Caddy reverse proxy. Authentication is enforced by Caddy's basic auth;
  # code-server itself binds to localhost with `--auth none`.
  options.services.workstation.coder = {
    enable = lib.mkEnableOption "Coder — VS Code in the browser (code-server)";

    package = lib.mkPackageOption pkgs "code-server" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "developer";
      description = "User the code-server service runs as.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Interface code-server binds to. Keep on localhost behind the reverse proxy.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port code-server listens on.";
    };

    workspace = lib.mkOption {
      type = lib.types.path;
      default = "/home/${cfg.user}";
      description = "Folder code-server opens by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.workstation-coder = {
      description = "Coder — VS Code in the browser (code-server)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment.HOME = "/home/${cfg.user}";

      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";
        ExecStart = "${lib.getExe cfg.package} --bind-addr ${cfg.host}:${toString cfg.port} --auth none --disable-telemetry ${cfg.workspace}";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}
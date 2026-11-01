{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.workstation.browserTerminal;
in
{
  options.services.workstation.browserTerminal = {
    enable = lib.mkEnableOption "browser terminal (ttyd)";

    package = lib.mkPackageOption pkgs "ttyd" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "developer";
      description = "User the terminal sessions run as.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Interface ttyd binds to. Keep on localhost behind the reverse proxy.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = "Port ttyd listens on.";
    };

    basePath = lib.mkOption {
      type = lib.types.str;
      default = "/terminal";
      description = "Path the browser terminal is served under, matching the Caddy reverse proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.workstation-browser-terminal = {
      description = "Browser terminal (ttyd)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment.HOME = "/home/${cfg.user}";

      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = "/home/${cfg.user}";
        ExecStart = "${lib.getExe cfg.package} --interface ${cfg.host} --port ${toString cfg.port} --base-path ${cfg.basePath} ${pkgs.bash}/bin/bash";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}

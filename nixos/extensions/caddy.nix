{ config, lib, pkgs, modulesPath, ... }:

let
  cfg = config.services.workstation.caddy;

  # Initial website password: a bcrypt hash of an unguessable random value that
  # has been discarded. The site stays closed (no one can authenticate) until
  # `web-access` rotates in a real password and restarts Caddy.
  placeholderHash = "$2a$14$njXok7jlCI5a4t3cy/3wVei/L37b5orbuMpr9xAHVe2NHZ32lpTOu";

  cert = "/var/lib/caddy/workstation-cert.pem";
  key = "/var/lib/caddy/workstation-key.pem";

  # A self-signed certificate generated at boot, outside the Nix store. Caddy's
  # `tls internal` cannot serve the empty SNI that browsers send for
  # `https://IP`, so the workstation serves an explicit default certificate.
  certGenerator = pkgs.writeShellScript "workstation-web-cert" ''
    set -euo pipefail
    cert="${cert}"
    key="${key}"

    if [[ ! -s "$cert" || ! -s "$key" ]]; then
      mkdir -p /var/lib/caddy
      ip=$(${pkgs.curl}/bin/curl -fs --max-time 5 \
        -H "Metadata-Flavor: Google" \
        http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip \
        2>/dev/null || true)
      subject_alt_name="DNS:workstation,DNS:localhost"
      if [[ -n "$ip" ]]; then
        subject_alt_name="$subject_alt_name,IP:$ip"
      fi
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
        -keyout "$key" -out "$cert" -days 825 \
        -subj "/CN=workstation" \
        -addext "subjectAltName=$subject_alt_name"
      chown caddy:caddy "$cert" "$key"
      chmod 0644 "$cert"
      chmod 0600 "$key"
    fi
  '';
in
{
  options.services.workstation.caddy = {
    enable = lib.mkEnableOption "HTTPS reverse proxy (Caddy) for browser access";

    package = lib.mkPackageOption pkgs "caddy" { };

    passwordFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/workstation/caddy.env";
      description = ''
        Environment file consumed by the Caddy unit holding
        `WORKSTATION_WEB_PASSWORD_HASH`. It lives outside the Nix store and is
        rewritten by the `web-access` rotation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/workstation 0750 root root -"
      "f ${cfg.passwordFile} 0600 root root - WORKSTATION_WEB_PASSWORD_HASH=${placeholderHash}"
    ];

    # Expose the caddy binary on the system PATH: the `web-access` rotation
    # uses `caddy hash-password`, and admins use caddy directly.
    environment.systemPackages = [ cfg.package ];

    systemd.services.workstation-web-cert = {
      description = "Generate the workstation self-signed web certificate";
      wantedBy = [ "multi-user.target" ];
      before = [ "caddy.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = certGenerator;
      };
    };

    # Caddy starts only after the certificate exists.
    systemd.services.caddy.wants = [ "workstation-web-cert.service" ];
    systemd.services.caddy.after = [ "workstation-web-cert.service" ];

    services.caddy = {
      enable = true;
      package = cfg.package;
      environmentFile = cfg.passwordFile;
      openFirewall = true;
      virtualHosts.":443" = {
        extraConfig = ''
          tls ${cert} ${key}
          basic_auth * {
            opencode {env.WORKSTATION_WEB_PASSWORD_HASH}
          }
          @terminal {
            path /terminal /terminal/*
          }
          handle @terminal {
            reverse_proxy 127.0.0.1:${toString config.services.workstation.browserTerminal.port}
          }
          handle {
            reverse_proxy 127.0.0.1:${toString config.services.workstation.opencode.port}
          }
        '';
      };
    };
  };
}
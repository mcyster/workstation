{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.workstation.idleShutdown;

  checker = pkgs.writeShellScript "workstation-idle-check" ''
    set -euo pipefail
    last_file=/var/lib/workstation/last-activity

    # Active if anyone is logged in, if there is an established connection on
    # an access port (SSH, HTTPS, or the local backend ports), or if the
    # machine is doing heavy work (for example a long build).
    if who -s 2>/dev/null | grep -q .; then
      rm -f "$last_file"
      exit 0
    fi
    if ss -Htn state established 2>/dev/null | awk '
        { split($4, a, ":"); p = a[length(a)] }
        p == 22 || p == 80 || p == 443 || p == 7681 || p == 10999 { found = 1 }
        END { exit !found }
      '; then
      rm -f "$last_file"
      exit 0
    fi
    load1=$(awk '{ print $1 }' /proc/loadavg)
    if awk -v l="$load1" 'BEGIN { exit !(l >= 2.0) }'; then
      rm -f "$last_file"
      exit 0
    fi

    # Record when the machine first looks idle, then shut it down once it has
    # stayed idle for the full timeout.
    now=$(date +%s)
    if [[ ! -f "$last_file" ]]; then
      printf '%s\n' "$now" > "$last_file"
      exit 0
    fi
    last=$(cat "$last_file")
    if (( now - last >= ${toString cfg.idleMinutes} * 60 )); then
      rm -f "$last_file"
      ${pkgs.systemd}/bin/systemctl poweroff -i
    fi
  '';
in
{
  options.services.workstation.idleShutdown = {
    enable = lib.mkEnableOption "shut the workstation down when it stays idle";

    idleMinutes = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "How long the workstation must stay idle before it shuts down.";
    };

    checkInterval = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Seconds between idle checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.workstation-idle-shutdown = {
      description = "Shut down the workstation after it stays idle";
      wantedBy = [ "multi-user.target" ];
      # The checker uses awk (gawk), ss (iproute2), and who/date (coreutils).
      path = with pkgs; [ coreutils gawk gnugrep iproute2 ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        ExecStart = checker;
      };
    };

    systemd.timers.workstation-idle-shutdown = {
      description = "Periodic idle shutdown check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = 0;
        OnUnitActiveSec = cfg.checkInterval;
        AccuracySec = "30s";
      };
    };
  };
}

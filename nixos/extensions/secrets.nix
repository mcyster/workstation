{ config, lib, ... }:

let
  cfg = config.services.workstation.secrets;
  names = builtins.attrNames cfg;

  # Declarative restart manifest, one file per secret listing the units to
  # restart after it is rewritten. Unit names are not secret, so they may live
  # in the store; the secrets action reads /etc/workstation/secrets/NAME.
  restartManifests = lib.listToAttrs (map (name:
    lib.nameValuePair "workstation/secrets/${name}" {
      text = lib.concatStringsSep "\n" cfg.${name}.units + "\n";
    }
  ) names);
in
{
  # Generic user environment secrets. Each entry names a secret file
  # (.env.NAME under /var/lib/workstation/secrets and /home/developer) and
  # lists the systemd units to restart after the `secrets` action rewrites it.
  # Secrets with no units (for example a CLI tool that only sources the env
  # file as the developer) are still written but nothing is restarted.
  #
  # No placeholder env file is created here. The `secrets` action writes the
  # file, and units load it only when it exists: their EnvironmentFile entries
  # use a `-` prefix, which systemd skips when the file is missing.
  options.services.workstation.secrets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.units = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Systemd units to restart after this secret changes.";
      };
    });
    default = { };
    example = {
      opencode.units = [ "opencode" ];
      tog.units = [ ];
    };
  };

  config = lib.mkIf (names != [ ]) {
    environment.etc = restartManifests;
  };
}

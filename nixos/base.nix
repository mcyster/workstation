{
  config,
  lib,
  pkgs,
  ...
}:

{
  # The developer account is the human surface of the workstation. SSH keys are
  # injected by the Google guest agent from instance metadata, so no keys are
  # declared here.
  users.users.developer = {
    isNormalUser = true;
    description = "Workstation developer";
    group = "users";
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
    homeMode = "0700";
  };

  # The developer authenticates through GCE-injected SSH keys or the serial
  # console recovery password (see gce.nix). Grant passwordless sudo.
  security.sudo.wheelNeedsPassword = false;

  # Nix with flakes, reproducible lock files, and automatic garbage collection.
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
  };

  # direnv with the persistent nix-direnv backend, wired into login shells.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      pull.ff = "only";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    gh
    htop
    jq
    nixfmt
    openssl
    ripgrep
    tmux
    tree
    vim
    wget
  ];

  environment.variables.EDITOR = "vim";
}

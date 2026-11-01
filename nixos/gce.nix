{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    # Provides the GCE guest agent, disk layout, kernel parameters, and the
    # `system.build.googleComputeImage` image builder (imports the
    # google-compute-config used by the running machine, so the image and the
    # deployed workstation stay consistent).
    (modulesPath + "/virtualisation/google-compute-image.nix")
  ];

  system.stateVersion = "26.11";

  networking.hostName = "workstation";

  # Google OS Login remaps accounts to Google IAM identities. The workstation
  # instead exposes a stable `developer` account whose keys are injected from
  # instance metadata by the guest agent.
  security.googleOsLogin.enable = lib.mkForce false;

  # Root recovery password for serial-console access. The file lives outside
  # the Nix store and is rewritten by the `web-access` rotation; it starts
  # locked ("!") so no login is possible until a password is deliberately set.
  users.users.root.hashedPasswordFile = "/var/lib/workstation/recovery-password";

  systemd.tmpfiles.rules = [
    "d /var/lib/workstation 0750 root root -"
    "f /var/lib/workstation/recovery-password 0600 root root - !"
  ];

  # Keep a boot menu with recent generations so a bad rebuild can be rolled
  # back from the GCE serial console, and expose that menu over the serial
  # port. The nixpkgs GCE module slims these down by default.
  boot.loader.timeout = lib.mkForce 5;
  boot.loader.grub.configurationLimit = lib.mkForce 8;
  boot.loader.grub.extraConfig = ''
    serial --unit=0 --speed=115200 --parity=no --stop=1
    terminal_input serial console
    terminal_output serial console
  '';

  # Serial console login (in addition to the GRUB menu) for out-of-band
  # recovery. kernelParams already include console=ttyS0.
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };

  # GCE firewall rules are still the outer gate, but keep an internal firewall
  # as defense in depth. Only SSH and HTTPS are exposed.
  networking.firewall.enable = lib.mkForce true;
  networking.firewall.allowedTCPPorts = [
    22
    443
  ];
}

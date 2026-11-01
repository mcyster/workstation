{
  description = "NixOS workstation for Google Compute Engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";

      # Modules shared by the minimal GCE image and the running workstation.
      baseModules = [
        ./nixos/base.nix
        ./nixos/gce.nix
      ];

      # The complete workstation configuration (base + extensions).
      workstationModule = ./nixos/configuration.nix;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      packages.${system} = {
        # Minimal GCE-compatible NixOS image. It deliberately contains only the
        # base workstation so it stays small, generic, and cheap to rebuild.
        # Extensions and the full workstation are applied later on the running
        # machine with ordinary `nixos-rebuild switch` deploys.
        gceImage =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = baseModules;
          }).config.system.build.googleComputeImage;
      };

      # Complete workstation, applied to a running GCE instance with
      # `nixos-rebuild switch --flake /path/to/this/repo#workstation`.
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ workstationModule ];
      };

      # Real build checks so `nix flake check` validates more than evaluation:
      # the full workstation closure and the GCE disk image.
      checks.${system} = {
        toplevel = self.nixosConfigurations.workstation.config.system.build.toplevel;
        gceImage = self.packages.${system}.gceImage;
      };

      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.google-cloud-sdk
              pkgs.gh
              pkgs.jq
            ];

            shellHook = ''
              if root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null)"; then
                export PATH="$root/scripts:$PATH"
              fi
              unset root
            '';
          };
        }
      );
    };
}

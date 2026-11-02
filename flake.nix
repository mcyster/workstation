{
  description = "NixOS workstation for Google Compute Engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";

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
        # The GCE image IS the complete workstation (a bootstrap server):
        # base system plus every extension. `create` boots it directly, so
        # publishing the image is a separate, occasional step (see
        # infra/workstation/publish-image) instead of something every create
        # does.
        gceImage =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ workstationModule ];
          }).config.system.build.googleComputeImage;
      };

      # Complete workstation, applied to a running GCE instance with
      # `nixos-rebuild switch --flake /path/to/this/repo#workstation`.
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ workstationModule ];
      };

      # Real build checks so `nix flake check` validates more than evaluation.
      # The toplevel is the complete workstation; the GCE image is validated
      # by the publish-image workflow rather than rebuilt on every CI run.
      checks.${system}.toplevel = self.nixosConfigurations.workstation.config.system.build.toplevel;

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

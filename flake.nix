{
  description = "Adaptive sakoora.hyprlock themes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      homeManagerModules = {
        default = self.homeManagerModules.sakoora-hyprlock;
        sakoora-hyprlock = import ./nix/home-manager.nix { inherit self; };
      };

      nixosModules = {
        default = self.nixosModules.sakoora-hyprlock;
        sakoora-hyprlock = import ./nix/nixos.nix;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          preview =
            style:
            import ./nix/preview.nix {
              inherit pkgs style;
              source = self;
            };
        in
        {
          default = self.packages.${system}.style-1;
          style-1 = preview 1;
          style-2 = preview 2;
        }
      );

      apps = forAllSystems (system: {
        default = self.apps.${system}.style-1;
        style-1 = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.style-1;
          meta.description = "Preview sakoora.hyprlock style 1";
        };
        style-2 = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.style-2;
          meta.description = "Preview sakoora.hyprlock style 2";
        };
      });
    };
}

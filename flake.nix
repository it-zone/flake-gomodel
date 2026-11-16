{
  description = "GoModel - fast, resource-efficient AI gateway";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          gomodel = pkgs.callPackage ./package.nix { };
        in
        {
          inherit gomodel;
          default = gomodel;
        }
      );

      overlays.default = final: _prev: {
        gomodel = final.callPackage ./package.nix { };
      };

      nixosModules.gomodel =
        { pkgs, ... }:
        {
          imports = [ ./module.nix ];
          services.gomodel.package =
            nixpkgs.lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.gomodel;
        };

      nixosModules.default = self.nixosModules.gomodel;
    };
}

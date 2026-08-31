{
  description = "Grok Bot desktop agent";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      packages = forAllSystems (system: rec {
        grok-bot = (pkgsFor system).callPackage ./package.nix { };
        default = grok-bot;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/grok-bot";
          meta.description = "Grok Bot desktop agent";
        };
      });

      overlays.default = final: _prev: {
        grok-bot = final.callPackage ./package.nix { };
      };

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      checks = forAllSystems (system: {
        grok-bot = self.packages.${system}.grok-bot;
      });
    };
}

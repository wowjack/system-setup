{
  description = "Declarative NixOS + Home Manager configuration for my workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Prebuilt, weekly-updated package/file index for comma and command-not-found.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-index-database,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkNixos =
        hardwareModule:
        nixpkgs.lib.nixosSystem {
          modules = [
            home-manager.nixosModules.home-manager
            nix-index-database.nixosModules.nix-index
            ./hosts/nixos
            hardwareModule
          ];
        };

      # Generated on the target machine by nixos-generate-config (see README.md).
      # Until it exists (and is `git add`ed — flakes ignore untracked files) there is
      # deliberately no `nixos` configuration, so a system with made-up disks can't be built.
      hardwareConfig = ./hosts/nixos/hardware-configuration.nix;
    in
    {
      nixosConfigurations = nixpkgs.lib.optionalAttrs (builtins.pathExists hardwareConfig) {
        nixos = mkNixos hardwareConfig;
      };

      checks.${system} = import ./checks {
        inherit pkgs self;
        hmLib = home-manager.lib.hm;
        nixos = mkNixos ./checks/stub-hardware.nix;
      };

      formatter.${system} = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          nixfmt-tree
          statix
          deadnix
          nil
          ruff
        ];
      };
    };
}

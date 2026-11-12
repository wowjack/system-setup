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
    # Declarative disk partitioning (hosts/nixos/disko.nix). `latest` follows releases.
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Decrypts the sops-encrypted files in secrets/ on the machine (modules/nixos/secrets.nix).
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-index-database,
      disko,
      sops-nix,
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
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./hosts/nixos
            hardwareModule
          ];
        };

      # Generated on the target machine by nixos-generate-config (see README.md).
      # Until it exists (and is `git add`ed — flakes ignore untracked files) there is
      # deliberately no `nixos` configuration, so a system with made-up hardware can't be built.
      hardwareConfig = ./hosts/nixos/hardware-configuration.nix;
    in
    {
      nixosConfigurations = nixpkgs.lib.optionalAttrs (builtins.pathExists hardwareConfig) {
        nixos = mkNixos hardwareConfig;
      };

      checks.${system} = import ./checks {
        inherit pkgs self;
        hmLib = home-manager.lib.hm;
        diskoLib = disko.lib;
        sopsModule = sops-nix.nixosModules.sops;
        homeManagerModule = home-manager.nixosModules.home-manager;
        nixos = mkNixos ./checks/stub-hardware.nix;
      };

      # The disko CLI at the version pinned in flake.lock, for installing (see README.md).
      packages.${system}.disko = disko.packages.${system}.disko;

      formatter.${system} = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          nixfmt-tree
          statix
          deadnix
          nil
          ruff
          # Encrypting and editing secrets/ (README.md, "Secrets").
          sops
          age
          mkpasswd
        ];
      };
    };
}

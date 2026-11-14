{
  description = "Declarative NixOS + Home Manager configuration for my machines";

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
    # Declarative disk partitioning (hosts/<host>/disko.nix). `latest` follows releases.
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Decrypts the sops-encrypted files in secrets/ on the machine (modules/nixos/secrets.nix).
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Claude code
    claude-code = {
      url = "github:sadjow/claude-code-nix";
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
      claude-code,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;

      # One directory per machine under hosts/, named like the machine's hostname
      # (nh picks the configuration by hostname). See ARCHITECTURE.md, "Hosts".
      hosts = [ "desktop" ];

      mkNixos =
        host: hardwareModule:
        nixpkgs.lib.nixosSystem {
          modules = [
            home-manager.nixosModules.home-manager
            nix-index-database.nixosModules.nix-index
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            { nixpkgs.overlays = [ claude-code.overlays.default ]; }
            ./hosts/${host}
            hardwareModule
          ];
        };

      # A host's hardware configuration is generated on the machine by
      # nixos-generate-config (see README.md). Until it exists (and is `git add`ed:
      # flakes ignore untracked files) the host deliberately has no configuration,
      # so a system with made-up hardware can't be built.
      installedHosts = builtins.filter (
        host: builtins.pathExists ./hosts/${host}/hardware-configuration.nix
      ) hosts;
    in
    {
      nixosConfigurations = lib.genAttrs installedHosts (
        host: mkNixos host ./hosts/${host}/hardware-configuration.nix
      );

      checks.${system} = import ./checks {
        inherit pkgs self;
        hmLib = home-manager.lib.hm;
        diskoLib = disko.lib;
        # The function the disko CLI evaluates (README.md, "Installing", step 4).
        diskoCli = import "${disko}/cli.nix";
        sopsModule = sops-nix.nixosModules.sops;
        homeManagerModule = home-manager.nixosModules.home-manager;
        # Every host, installed or not, evaluated against stub hardware.
        systems = lib.genAttrs hosts (host: mkNixos host ./checks/stub-hardware.nix);
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

# Checks run by `nix flake check` (which additionally evaluates nixosConfigurations).
{
  pkgs,
  self,
  hmLib,
  diskoLib,
  sopsModule,
  homeManagerModule,
  # The full system, evaluated against ./stub-hardware.nix.
  nixos,
}:
let
  home = nixos.config.home-manager.users.user;
in
{
  # Evaluate the whole system (every module, assertion and package derivation)
  # without building it. Catches option typos, type errors, and disallowed unfree
  # packages before the real hardware-configuration.nix exists.
  # Also instantiates disko's install-time partitioning script for hosts/nixos/disko.nix.
  nixos-eval =
    let
      inherit (nixos.config.system.build) toplevel diskoScript;
    in
    builtins.deepSeq [ toplevel.drvPath diskoScript.drvPath ] (
      pkgs.runCommand "nixos-eval" { } "touch $out"
    );

  # The disk layout formats, mounts and boots (VM test; needs KVM).
  disko-layout = import ./disko-layout.nix { inherit pkgs diskoLib; };

  # Secrets are decrypted and installed: login password, SSH keys, WireGuard
  # profiles (VM test; needs KVM).
  secrets = import ./secrets.nix { inherit pkgs sopsModule homeManagerModule; };

  # The WireGuard profile converter (modules/nixos/wireguard/nm_profile.py).
  wireguard-profile = import ./wireguard-profile.nix { inherit pkgs; };

  # Every dconf key exists and has the type its GSettings schema expects.
  dconf = import ./dconf.nix {
    inherit pkgs hmLib;
    inherit (home.dconf) settings;
  };

  # The generated hyprland.lua loads without errors.
  hyprland-config =
    pkgs.runCommand "check-hyprland-config" { nativeBuildInputs = [ pkgs.hyprland ]; }
      ''
        export HOME="$TMPDIR" XDG_RUNTIME_DIR="$TMPDIR/runtime"
        mkdir -m 700 "$XDG_RUNTIME_DIR"
        args=()
        # Hyprland refuses to start as root. Nix builds run as root when Nix has no
        # build users (single-user Nix, e.g. inside a container).
        if [ "$(id -u)" -eq 0 ]; then args+=(--i-am-really-stupid); fi
        Hyprland --verify-config --config ${home.xdg.configFile."hypr/hyprland.lua".source} "''${args[@]}"
        touch $out
      '';

  lint =
    pkgs.runCommand "lint"
      {
        nativeBuildInputs = with pkgs; [
          nixfmt
          statix
          deadnix
          ruff
        ];
      }
      ''
        cd ${self}
        find . -name '*.nix' -print0 | xargs -0 nixfmt --check
        statix check .
        deadnix --fail .
        ruff check --no-cache .
        ruff format --check --no-cache .
        touch $out
      '';
}

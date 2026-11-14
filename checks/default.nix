# Checks run by `nix flake check` (which additionally evaluates nixosConfigurations).
{
  pkgs,
  self,
  hmLib,
  diskoLib,
  diskoCli,
  sopsModule,
  homeManagerModule,
  # Every host's full system, evaluated against ./stub-hardware.nix: { <host> = nixosSystem; }.
  systems,
}:
let
  inherit (pkgs) lib;
  # The desktop and Home Manager checks below test the configuration the desktop
  # host uses (modules/nixos, home/).
  nixos = systems.desktop;
  home = nixos.config.home-manager.users.user;

  # A derivation that fails with `message` unless `ok`.
  assertCheck =
    name: ok: message:
    pkgs.runCommand name { } (
      if ok then
        "touch $out"
      else
        ''
          echo ${lib.escapeShellArg message} >&2
          exit 1
        ''
    );
in
# Evaluate each host's whole system (every module, assertion and package
# derivation) without building it. Catches option typos, type errors, and
# disallowed unfree packages before the host's real hardware-configuration.nix
# exists. Also instantiates disko's partitioning script for hosts/<host>/disko.nix,
# both through the NixOS module and exactly as the install command in README.md
# builds it with the disko CLI. And checks the hostname matches the directory
# name, which `nh os switch` relies on to pick the host's configuration.
lib.mapAttrs' (
  host: system:
  lib.nameValuePair "nixos-eval-${host}" (
    let
      inherit (system.config.system.build) toplevel diskoScript;
      diskoCliScript = diskoCli {
        inherit pkgs;
        mode = "destroy,format,mount";
        diskoFile = ../hosts/${host}/disko.nix;
        device = "/dev/disk/by-id/check";
      };
      inherit (system.config.networking) hostName;
    in
    assert lib.assertMsg (
      hostName == host
    ) "hosts/${host}: networking.hostName is \"${hostName}\", must be \"${host}\"";
    builtins.deepSeq [ toplevel.drvPath diskoScript.drvPath diskoCliScript.drvPath ] (
      pkgs.runCommand "nixos-eval-${host}" { } "touch $out"
    )
  )
) systems
// {
  # The disk layout formats, mounts and boots (VM test; needs KVM).
  disko-layout = import ./disko-layout.nix { inherit pkgs diskoLib; };

  # Secrets are decrypted and installed: login password, SSH keys, WireGuard
  # profiles (VM test; needs KVM).
  secrets = import ./secrets.nix { inherit pkgs sopsModule homeManagerModule; };

  # Every file under secrets/ is sops-encrypted (modules/nixos/secrets.nix).
  secrets-encrypted = nixos.config.system.build.secretsEncrypted;

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

  # Hyprland's helpers (bar, idle/lock, notifications, ...) never start in GNOME:
  # every user service started by hyprland-session.target is started by nothing else.
  hyprland-session-services =
    let
      target = "hyprland-session.target";
      helpers = lib.filterAttrs (
        _: service: builtins.elem target (service.Install.WantedBy or [ ])
      ) home.systemd.user.services;
      shared = lib.attrNames (
        lib.filterAttrs (_: service: service.Install.WantedBy != [ target ]) helpers
      );
    in
    assertCheck "hyprland-session-services" (helpers != { } && shared == [ ])
      "Hyprland helpers also wanted by other targets (they would start in GNOME too): ${lib.concatStringsSep ", " shared}";

  # utils/factorio-setup-symlinks.sh moves data and links it, and refuses conflicts.
  factorio-symlinks = import ./factorio-symlinks.nix { inherit pkgs; };

  lint =
    let
      # Written by nixos-generate-config on each machine (README.md, "Installing"):
      # their formatting and unused arguments are the generator's.
      generated = "hosts/*/hardware-configuration.nix";
    in
    pkgs.runCommand "lint"
      {
        nativeBuildInputs = with pkgs; [
          nixfmt
          statix
          deadnix
          ruff
          shellcheck
        ];
      }
      ''
        cd ${self}
        find . -name '*.nix' -not -path './${generated}' -print0 | xargs -0 nixfmt --check
        statix check --ignore '${generated}' .
        # --exclude takes file names (expanded by the shell) and any number of
        # them, so `--` ends the list; otherwise it swallows `.` and checks nothing.
        deadnix --fail --exclude ${generated} -- .
        ruff check --no-cache .
        ruff format --check --no-cache .
        find . -name '*.sh' -print0 | xargs -0 -r shellcheck
        touch $out
      '';
}

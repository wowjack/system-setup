# Nix itself and its tooling: flakes, nh, comma, store hygiene, and which
# proprietary packages are allowed.
{ lib, ... }:
{
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # This flake is the only source of truth; no mutable nix-channel state.
    # (nixosSystem already pins `nixpkgs` in the registry and NIX_PATH to this flake's input.)
    channel.enable = false;

    # Hard-link identical files in the store.
    optimise.automatic = true;
  };

  # nh: `nh os switch` etc. wrap nixos-rebuild, show which packages changed, and
  # only use sudo to activate.
  programs.nh = {
    enable = true;
    # Where README.md says to clone this repository; lets nh run from any directory.
    flake = "/home/user/repos/system-setup";
    # Weekly cleanup of old generations (system and Home Manager) and unreferenced
    # store paths, so the store doesn't grow forever. Keeps the last 14 days of
    # generations, and at least 5 for rollbacks. --keep-one keeps each direnv
    # project's current shell until the project directory itself is deleted.
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 5 --keep-one";
    };
  };

  # comma: `, <command>` runs any program from nixpkgs without installing it.
  # The nix-index-database module (flake.nix) also makes an unknown command
  # print which packages provide it, and adds `nix-locate`.
  programs.nix-index-database.comma.enable = true;

  # Proprietary packages must be listed explicitly, so the config documents every one installed.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "code" # VS Code's FHS wrapper (vscode.fhs)
      "discord"
      "obsidian"
      "slack"
      "steam"
      "steam-unwrapped"
      "vscode"
      "zoom"
    ];
}

# User-level applications. Removing a package from this list removes it from the
# system on the next switch; nothing is left behind except its data in ~.
#
# Language toolchains (Rust, Node, Go, Java, ...) are intentionally absent:
# declare them per project in a flake devShell and load them with direnv.
{ lib, pkgs, ... }:
let
  # Temporary. nixos-26.05 updated VS Code to 1.144.0, which fails to build
  # (its bundled ripgrep moved: https://github.com/NixOS/nixpkgs/issues/584492).
  # release-26.05 has reverted it to 1.119.0 (NixOS/nixpkgs#585279); until the
  # revert reaches the nixos-26.05 channel, this does the same. Once the pinned
  # nixpkgs no longer has 1.144.0, evaluation fails here: delete this and use
  # `vscode.fhs` again. (The FHS wrapper keeps the name code-1.144.0, but it
  # runs 1.119.0.)
  vscode_1_119 =
    lib.throwIfNot (pkgs.vscode.version == "1.144.0")
      "home/packages.nix: nixpkgs no longer has the broken VS Code 1.144.0; remove the 1.119.0 workaround"
      (
        pkgs.vscode.overrideAttrs {
          version = "1.119.0";
          src = pkgs.fetchurl {
            name = "VSCode_1.119.0_linux-x64.tar.gz";
            url = "https://update.code.visualstudio.com/1.119.0/linux-x64/stable";
            hash = "sha256-HcZIRGB0y8U5huxXN9jNrhMD0Jjmn+QNUU60EHGduXo=";
          };
        }
      );
in
{
  home.packages = with pkgs; [
    # Terminal
    btop
    curl
    ffmpeg
    neovim
    tmux
    tree
    wget
    amdgpu_top

    # Scratch Python for quick REPL work. Project dependencies belong in the
    # project's devShell; `pip install` into this interpreter is not possible.
    (python3.withPackages (ps: [ ps.ipython ]))

    # Editors and writing
    # FHS variant: extensions that download their own binaries (language servers,
    # debuggers) work as they would on a conventional distro.
    vscode_1_119.fhs
    obsidian
    libreoffice
    texliveMedium

    # Research
    zotero
    kdePackages.okular

    # Communication and internet
    firefox
    discord
    slack
    zoom-us
    qbittorrent

    # Media
    vlc
    obs-studio

    # Security
    bitwarden-desktop

    # LLMs
    claude-code

    # GNOME
    gnome-extension-manager
  ];
}

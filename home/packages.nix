# User-level applications. Removing a package from this list removes it from the
# system on the next switch; nothing is left behind except its data in ~.
#
# Language toolchains (Rust, Node, Go, Java, ...) are intentionally absent:
# declare them per project in a flake devShell and load them with direnv.
{ pkgs, ... }:
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

    # Scratch Python for quick REPL work. Project dependencies belong in the
    # project's devShell; `pip install` into this interpreter is not possible.
    (python3.withPackages (ps: [ ps.ipython ]))

    # Editors and writing
    # FHS variant: extensions that download their own binaries (language servers,
    # debuggers) work as they would on a conventional distro.
    vscode.fhs
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

    # GNOME
    gnome-extension-manager
  ];
}

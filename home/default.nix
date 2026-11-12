# Home Manager configuration for the account `user`: user packages, dotfiles and desktop settings.
# Applied together with the system by `nixos-rebuild switch`.
{
  imports = [
    ./shell.nix
    ./git.nix
    ./ssh.nix
    ./packages.nix
    ./desktop
  ];

  # The Home Manager release this config was first written for. It controls
  # defaults for stateful data; don't change it without reading the release notes.
  home.stateVersion = "26.05";
}

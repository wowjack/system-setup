{ pkgs, ... }:
let
  shared = import ./shared.nix { inherit pkgs; };
in
{
  imports = [
    ./gnome.nix
    ./hyprland.nix
  ];

  home.packages = [ shared.monospaceFont.package ];
  fonts.fontconfig.enable = true;
}

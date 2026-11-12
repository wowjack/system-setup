# Desktop preferences used by both the GNOME and Hyprland sessions, defined once.
{ pkgs }:
{
  wallpaper = pkgs.fetchurl {
    name = "f40-01-night.png";
    url = "https://raw.githubusercontent.com/fedoradesign/backgrounds/5aa35c2b7f6945b32a69382bb9092373fcbcb5d1/default/f40-01-night.png";
    hash = "sha256-5qx+VVb5LIOXHQai0N0gXbItAhPaZ00lEaa+lbCYllc=";
  };

  monospaceFont = {
    package = pkgs.nerd-fonts.roboto-mono;
    name = "RobotoMono Nerd Font Mono";
    size = 12;
  };

  keyboard = {
    repeatDelayMs = 250;
    repeatIntervalMs = 20;
    # XKB options, for example:
    #   [ "caps:escape" ]
    # Make a Windows-style bottom row resemble a Mac's: swap left Alt and left
    # Super, and turn right Alt into Super:
    #   [ "altwin:swap_lalt_lwin" "altwin:ralt_super" ]
    xkbOptions = [ ];
  };

  mouse = {
    accelProfile = "flat";
    speed = -0.2; # -1.0 .. 1.0
  };

  touchpad = {
    tapToClick = true;
    naturalScroll = true;
  };
}

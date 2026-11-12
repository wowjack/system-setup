{
  # Steam needs system-level integration (32-bit graphics drivers, udev rules for
  # controllers), so it is enabled here instead of as a user package.
  programs.steam.enable = true;
}

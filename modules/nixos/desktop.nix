# Graphical sessions and the hardware services they need.
# GDM offers two sessions: GNOME (the default) and Hyprland. Both share the same
# apps, settings (dconf), keyring and audio; Hyprland-only helpers are configured in
# home/desktop/hyprland.nix and only start inside a Hyprland session.
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  programs.hyprland.enable = true;
  # hyprlock (Hyprland's lock screen) authenticates through PAM.
  # Not using `programs.hyprlock.enable`: it also enables a system-wide hypridle
  # service that would start in GNOME sessions too.
  security.pam.services.hyprlock = { };

  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
}

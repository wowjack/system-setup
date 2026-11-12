# GNOME settings, written to dconf (carried over from the old gnome_config.toml).
# GTK apps also read many of these inside the Hyprland session (dark style,
# monospace font, file chooser behaviour).
#
# dconf is strongly typed and silently ignores values of the wrong type. Nix
# integers become int32, so uint32 keys need mkUint32. `nix flake check`
# validates every key and type below against the installed GSettings schemas.
{ lib, pkgs, ... }:
let
  inherit (lib.hm.gvariant) mkArray mkUint32 type;
  shared = import ./shared.nix { inherit pkgs; };
  wallpaperUri = "file://${shared.wallpaper}";
in
{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      accent-color = "blue";
      color-scheme = "prefer-dark";
      clock-format = "12h"; # matches the previous Debian install
      clock-show-weekday = true;
      clock-show-seconds = false;
      enable-hot-corners = true;
      show-battery-percentage = true;
      monospace-font-name = "${shared.monospaceFont.name} ${toString shared.monospaceFont.size}";
    };

    "org/gnome/desktop/background" = {
      picture-uri = wallpaperUri;
      picture-uri-dark = wallpaperUri;
    };
    "org/gnome/desktop/screensaver".picture-uri = wallpaperUri;

    "org/gnome/desktop/sound".event-sounds = false;

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      show-directory-item-counts = "always";
      show-hidden-files = true;
    };
    # File dialogs (and Nautilus, for "folders first") read these.
    # Nautilus has no sort-directories-first key of its own.
    "org/gtk/settings/file-chooser" = {
      show-hidden = true;
      sort-directories-first = true;
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
      sort-directories-first = true;
    };

    "org/gnome/mutter" = {
      center-new-windows = true;
      attach-modal-dialogs = false;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = shared.mouse.accelProfile;
      inherit (shared.mouse) speed;
    };
    "org/gnome/desktop/peripherals/keyboard" = {
      repeat = true;
      delay = mkUint32 shared.keyboard.repeatDelayMs;
      repeat-interval = mkUint32 shared.keyboard.repeatIntervalMs;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = shared.touchpad.tapToClick;
      natural-scroll = shared.touchpad.naturalScroll;
    };

    "org/gnome/desktop/wm/preferences".button-layout = "right:minimize,close";

    "org/gnome/desktop/input-sources".xkb-options = mkArray type.string shared.keyboard.xkbOptions;
  };
}

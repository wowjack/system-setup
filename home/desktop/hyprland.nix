# Hyprland session: a starter config that behaves like GNOME where it reasonably can
# (keybindings, top bar, Super opens the launcher, lock screen, auto-lock when idle)
# while keeping Hyprland's tiling. Nothing here runs in the GNOME session.
#
# Hyprland 0.55 is configured in Lua (~/.config/hypr/hyprland.lua) through the `hl`
# API: https://wiki.hypr.land/ . `nix flake check` runs `Hyprland --verify-config`
# on the generated file.
{ lib, pkgs, ... }:
let
  shared = import ./shared.nix { inherit pkgs; };
  toLua = lib.generators.toLua { };

  # User services below are started by this target, which the Home Manager Hyprland
  # module defines and Hyprland starts on login. GNOME never starts it.
  sessionTarget = "hyprland-session.target";
  hyprlandService = description: execStart: {
    Unit = {
      Description = description;
      PartOf = [ sessionTarget ];
      After = [ sessionTarget ];
    };
    Service = {
      ExecStart = execStart;
      Restart = "on-failure";
    };
    Install.WantedBy = [ sessionTarget ];
  };

  launcher = lib.getExe pkgs.fuzzel;
  terminal = lib.getExe' pkgs.gnome-console "kgx";
  fileManager = lib.getExe pkgs.nautilus;
  hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  playerctl = lib.getExe pkgs.playerctl;
  lockScreen = "${lib.getExe' pkgs.procps "pidof"} hyprlock || ${lib.getExe pkgs.hyprlock}";
  # GNOME Settings works outside GNOME when told it is running in GNOME.
  gnomeSettings =
    panel:
    "env XDG_CURRENT_DESKTOP=GNOME ${lib.getExe' pkgs.gnome-control-center "gnome-control-center"} ${panel}";

  # Like GNOME: save to ~/Pictures/Screenshots and copy to the clipboard.
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      slurp
      wl-clipboard
      xdg-user-dirs
    ];
    text = ''
      dir="$(xdg-user-dir PICTURES)/Screenshots"
      file="$dir/Screenshot From $(date '+%Y-%m-%d %H-%M-%S').png"
      mkdir -p "$dir"
      case "''${1:-}" in
        area)
          # slurp exits non-zero when the selection is cancelled with Escape.
          area="$(slurp -d)" || exit 0
          grim -g "$area" "$file"
          ;;
        screen)
          grim "$file"
          ;;
        *)
          echo "usage: screenshot area|screen" >&2
          exit 2
          ;;
      esac
      wl-copy --type image/png < "$file"
    '';
  };

  # Like GNOME's power-off menu.
  sessionMenu = pkgs.writeShellApplication {
    name = "session-menu";
    runtimeInputs = with pkgs; [
      fuzzel
      hyprshutdown
      systemd
    ];
    text = ''
      # fuzzel exits non-zero when the menu is dismissed.
      choice="$(printf '%s\n' Lock "Log Out" Suspend Restart "Power Off" | fuzzel --dmenu --prompt "Session: ")" || exit 0
      case "$choice" in
        Lock) ${lockScreen} ;;
        "Log Out") hyprshutdown ;; # asks apps to close, then exits Hyprland
        Suspend) systemctl suspend ;;
        Restart) systemctl reboot ;;
        "Power Off") systemctl poweroff ;;
        *)
          echo "unknown choice: $choice" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  # Make Home Manager's Wayland services (waybar, hypridle, polkit agent) start
  # with Hyprland only, instead of with any graphical session.
  wayland.systemd.target = sessionTarget;

  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland and its portal are installed by the NixOS module (modules/nixos/desktop.nix).
    package = null;
    portalPackage = null;
    configType = "lua";

    settings = {
      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = "auto";
      };

      env = [
        {
          _args = [
            "XCURSOR_THEME"
            "Adwaita"
          ];
        }
        {
          _args = [
            "XCURSOR_SIZE"
            "24"
          ];
        }
      ];

      config = {
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          col = {
            active_border = "rgb(3584e4)"; # GNOME's blue accent
            inactive_border = "rgba(595959aa)";
          };
        };
        decoration.rounding = 12; # like libadwaita windows
        input = {
          kb_layout = "us";
          kb_options = lib.concatStringsSep "," shared.keyboard.xkbOptions;
          repeat_delay = shared.keyboard.repeatDelayMs;
          # GNOME stores the repeat interval; Hyprland wants repeats per second.
          repeat_rate = 1000 / shared.keyboard.repeatIntervalMs;
          accel_profile = shared.mouse.accelProfile;
          sensitivity = shared.mouse.speed;
          # Like GNOME: clicking focuses a window; the pointer only decides where scrolling goes.
          follow_mouse = 2;
          touchpad = {
            natural_scroll = shared.touchpad.naturalScroll;
            tap_to_click = shared.touchpad.tapToClick;
          };
        };
        misc = {
          # The wallpaper comes from swaybg (below); don't flash Hyprland's own.
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };
      };

      # Like GNOME: three-finger horizontal swipe switches workspaces.
      gesture = {
        fingers = 3;
        direction = "horizontal";
        action = "workspace";
      };
    };

    # Keybindings mirror GNOME's defaults where an equivalent exists.
    extraConfig = ''
      local launcher    = ${toLua launcher}
      local terminal    = ${toLua terminal}
      local fileManager = ${toLua fileManager}
      local lockScreen  = ${toLua lockScreen}
      local sessionMenu = ${toLua (lib.getExe sessionMenu)}
      local screenshot  = ${toLua (lib.getExe screenshot)}
      local wpctl       = ${toLua wpctl}
      local playerctl   = ${toLua playerctl}

      -- Apps and session
      hl.bind("Super_L", hl.dsp.exec_cmd(launcher), { release = true }) -- tap Super: launcher (GNOME: Activities)
      hl.bind("SUPER + A", hl.dsp.exec_cmd(launcher))                   -- GNOME: show apps
      hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
      hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager))                -- GNOME: home folder
      hl.bind("SUPER + L", hl.dsp.exec_cmd(lockScreen))
      hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(sessionMenu))      -- GNOME: log out / power off
      hl.bind("Print", hl.dsp.exec_cmd(screenshot .. " area"))
      hl.bind("SHIFT + Print", hl.dsp.exec_cmd(screenshot .. " screen"))

      -- Windows
      hl.bind("ALT + F4", hl.dsp.window.close())
      hl.bind("SUPER + Up", hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }))
      hl.bind("SUPER + Down", hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
      hl.bind("ALT + F10", hl.dsp.window.fullscreen({ mode = "maximized" })) -- toggle
      -- GNOME snaps windows to the left/right half; here they move within the tiling layout.
      hl.bind("SUPER + Left", hl.dsp.window.move({ direction = "left" }))
      hl.bind("SUPER + Right", hl.dsp.window.move({ direction = "right" }))
      -- Hyprland-specific: take a window out of (or back into) the tiling layout.
      hl.bind("SUPER + F", hl.dsp.window.float({ action = "toggle" }))

      local function switchWindow(forward)
        return function()
          hl.dispatch(hl.dsp.window.cycle_next({ next = forward }))
          hl.dispatch(hl.dsp.window.bring_to_top())
        end
      end
      hl.bind("ALT + Tab", switchWindow(true))
      hl.bind("ALT + SHIFT + Tab", switchWindow(false))
      hl.bind("SUPER + Tab", switchWindow(true))
      hl.bind("SUPER + SHIFT + Tab", switchWindow(false))

      -- Super + drag moves a window (as in GNOME); Super + right-drag resizes it.
      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- Workspaces
      hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
      hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "r-1" }))
      hl.bind("CTRL + ALT + Right", hl.dsp.focus({ workspace = "r+1" }))
      hl.bind("CTRL + ALT + Left", hl.dsp.focus({ workspace = "r-1" }))
      hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }))
      hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }))
      hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
      -- GNOME uses Super+1..9 for dash favourites; with no dash, they pick workspaces.
      for i = 1, 9 do
        hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
        hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
      end

      -- Media keys (also work on the lock screen)
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(wpctl .. " set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd(wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(playerctl .. " play-pause"), { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd(playerctl .. " play-pause"), { locked = true })
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd(playerctl .. " next"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(playerctl .. " previous"), { locked = true })
    '';
  };

  # Top bar, laid out like GNOME's: workspaces left, clock centre, status right.
  programs.waybar = {
    enable = true;
    systemd.enable = true; # started by hyprland-session.target (see wayland.systemd.target)
    settings.topBar = {
      layer = "top";
      position = "top";
      # Display only: waybar 0.15 switches workspaces with legacy `hyprctl dispatch`
      # syntax, which Hyprland rejects when configured in Lua, so clicks do nothing.
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "network"
        "bluetooth"
        "pulseaudio"
        "custom/session"
      ];
      clock = {
        format = "{:%a %b %e  %I:%M %p}";
        tooltip-format = "<tt>{calendar}</tt>";
      };
      network = {
        format-wifi = "{essid}";
        format-ethernet = "Wired";
        format-disconnected = "Offline";
        on-click = gnomeSettings "network";
      };
      bluetooth = {
        format = "BT";
        format-off = "";
        format-disabled = "";
        format-connected = "BT {device_alias}";
        on-click = gnomeSettings "bluetooth";
      };
      pulseaudio = {
        format = "Vol {volume}%";
        format-muted = "Muted";
        on-click = gnomeSettings "sound";
      };
      "custom/session" = {
        format = "⏻";
        tooltip = false;
        on-click = lib.getExe sessionMenu;
      };
    };
    style = ''
      * {
        font-family: "Adwaita Sans", sans-serif;
        font-size: 14px;
      }
      window#waybar {
        background: #000000;
        color: #ffffff;
      }
      #workspaces button {
        color: #ffffff;
        padding: 0 6px;
      }
      #workspaces button.active {
        background: #3584e4;
      }
      #clock {
        font-weight: bold;
      }
      #tray, #network, #bluetooth, #pulseaudio, #custom-session {
        padding: 0 10px;
      }
    '';
  };

  # Launcher (Super). It lists the same .desktop apps as GNOME's app grid.
  programs.fuzzel = {
    enable = true;
    settings.main = {
      font = "Adwaita Sans:size=12";
      inherit terminal;
    };
  };

  # Lock screen, based on hyprlock's bundled example. PAM is set up in modules/nixos/desktop.nix.
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;
      background = [
        {
          monitor = "";
          path = "${shared.wallpaper}";
          blur_passes = 3;
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "20%, 5%";
          outline_thickness = 3;
          fade_on_empty = false;
          rounding = 15;
          placeholder_text = "Password";
          fail_text = "$PAMFAIL";
          position = "0, -20";
          halign = "center";
          valign = "center";
        }
      ];
      label = [
        {
          monitor = "";
          text = "$TIME";
          font_size = 90;
          position = "0, 200";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  # Like GNOME's defaults: lock and blank the screen after 5 minutes idle.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = lockScreen;
        before_sleep_cmd = "loginctl lock-session";
        # With a Lua config, `hyprctl dispatch` takes Lua dispatcher expressions.
        after_sleep_cmd = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"on\" })'";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330;
          on-timeout = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"off\" })'";
          on-resume = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"on\" })'";
        }
      ];
    };
  };

  # Authentication dialogs for apps that ask for admin rights (GNOME Shell has its own).
  services.hyprpolkitagent.enable = true;

  # GNOME Shell provides these in GNOME; Hyprland needs separate programs.
  # Plain user services (not Home Manager's D-Bus-activated `services.mako`) so the
  # notification daemon can never be started inside GNOME.
  systemd.user.services = {
    mako = hyprlandService "Notification daemon" (lib.getExe pkgs.mako);
    swaybg = hyprlandService "Wallpaper" "${lib.getExe pkgs.swaybg} --image ${shared.wallpaper} --mode fill";
  };
}

Dotfiles and stuff for my workstation: NixOS 26.05 for the system and
Home Manager for my user.

## Everyday commands

The `nh os` commands work from any directory & use this repository at
`~/repos/system-setup`

| Task                                                        | Command                                                                                           |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Apply the configuration                                     | `nh os switch`                                                                                    |
| Apply until next reboot only (try something out)            | `nh os test`                                                                                      |
| Build without applying                                      | `nh os build`                                                                                     |
| Update all packages                                         | `nix flake update`, then `nh os switch`, then commit `flake.lock`                                 |
| Undo the last switch                                        | `nh os rollback` (or pick an older entry in the boot menu)                                        |
| Run a program without installing it                         | `, <command>`                                                                                     |
| Find which package has a command or file                    | type the command, or `nix-locate bin/<command>`                                                   |
| Find a package or option                                    | `nh search <name>`, or <https://search.nixos.org> and <https://home-manager-options.extranix.com> |
| Free disk space now                                         | `nh clean all --keep-since 14d --keep 5 --keep-one` (also runs weekly)                            |
| Run all checks                                              | `nix flake check`                                                                                 |
| Format the Nix files                                        | `nix fmt`                                                                                         |
| Development shell (formatter, linters, Nix language server) | `nix develop`, or `direnv allow` once                                                             |

`nh os` builds unprivileged and uses sudo only to activate the result, so Nix never
reads this repository as root. Before switching, it shows which packages will
be added, removed or upgraded. Flakes only see files tracked by git: `git add`
new files before rebuilding.

## Installing on a new machine

1. Install NixOS 26.05 from the graphical ISO. Create the user `user`. The
   desktop you pick in the installer doesn't matter; this configuration
   replaces it.
2. In a terminal on the new system, get this repository:

   ```sh
   nix-shell -p git gh   # gh only if the repository is private: run `gh auth login`
   git clone https://github.com/wowjack/system-setup.git ~/repos/system-setup
   cd ~/repos/system-setup
   ```

3. Add the hardware configuration the installer generated for this machine
   (disks, kernel modules, CPU microcode). Until this file exists, the flake
   deliberately has no `nixos` configuration.

   ```sh
   cp /etc/nixos/hardware-configuration.nix hosts/nixos/
   git add hosts/nixos/hardware-configuration.nix
   ```

   If you enabled disk encryption in the installer, also copy any
   `boot.initrd.luks.devices` and `boot.initrd.secrets` lines from
   `/etc/nixos/configuration.nix` into `hosts/nixos/default.nix`. Otherwise
   the system will not be able to unlock its disk at boot.

4. Build the configuration and make it the boot default:

   ```sh
   nixos-rebuild boot --flake .#nixos --sudo
   ```

   (nh isn't installed until this configuration is applied, so the first
   build uses `nixos-rebuild` directly.)

5. Reboot, then commit `hosts/nixos/hardware-configuration.nix`. It contains
   disk UUIDs, not secrets.

### Finishing checklist

- Create an SSH key and add it to GitHub: `ssh-keygen -t ed25519`, then
  `cat ~/.ssh/id_ed25519.pub`.
- Clone `obsidian_notes` and open `obsidian_notes/notes` as the vault in Obsidian.
- Import the ProtonVPN WireGuard configuration in GNOME Settings › Network ›
  VPN › Import from file (or `nmcli connection import type wireguard file <file>.conf`).
  If the tunnel connects but no traffic flows, NixOS's firewall reverse-path
  filter is likely dropping it; set `networking.firewall.checkReversePath = "loose";`.
- In VS Code, install the *direnv* extension (`mkhl.direnv`) so the editor
  sees each project's devShell.

## Per-project toolchains with direnv

Put a `flake.nix` in the project with its tools, and an `.envrc` containing
`use flake`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.cargo pkgs.rustc pkgs.rust-analyzer pkgs.clippy ];
      };
    };
}
```

```sh
echo "use flake" > .envrc
direnv allow   # trust this .envrc; repeat after you edit it
```

## What's installed

| Area           | Where                              | Contents                                                                                                                                              |
| -------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nix tooling    | `modules/nixos/nix.nix`            | nh, comma, nix-index (command-not-found, `nix-locate`)                                                                                                |
| Desktop        | `modules/nixos/desktop.nix`        | GDM, GNOME, Hyprland, NetworkManager, Bluetooth, PipeWire                                                                                             |
| Gaming         | `modules/nixos/gaming.nix`         | Steam                                                                                                                                                 |
| Virtualisation | `modules/nixos/virtualisation.nix` | rootless Docker, libvirt/QEMU/KVM, virt-manager                                                                                                       |
| Terminal       | `home/packages.nix`                | btop, curl, wget, tree, tmux, neovim, ffmpeg, Python + ipython                                                                                        |
| Shell and git  | `home/shell.nix`, `home/git.nix`   | bash, direnv + nix-direnv, git identity                                                                                                               |
| Applications   | `home/packages.nix`                | VS Code, Obsidian, LibreOffice, TeX Live (medium), Zotero, Okular, Firefox, Discord, Slack, Zoom, qBittorrent, VLC, OBS, Bitwarden, Extension Manager |
| GNOME settings | `home/desktop/gnome.nix`           | dark style, blue accent, RobotoMono Nerd Font, wallpaper, Nautilus, input                                                                             |
| Hyprland       | `home/desktop/hyprland.nix`        | see below                                                                                                                                             |

### Hyprland session

Keybindings follow GNOME's defaults where an equivalent exists:

| Keys | Action |
| --- | --- |
| Super (tap), Super+A | App launcher (fuzzel) |
| Ctrl+Alt+T / Super+E | Terminal (GNOME Console) / Files |
| Super+L | Lock screen |
| Ctrl+Alt+Delete, ⏻ in the top bar | Lock / log out / suspend / restart / power off |
| Print / Shift+Print | Screenshot of an area / of the screen, saved to ~/Pictures/Screenshots and copied |
| Alt+F4 | Close window |
| Super+Up / Super+Down / Alt+F10 | Maximize / restore / toggle maximize |
| Super+Left / Super+Right | Move window within the tiling layout |
| Super+F | Toggle floating for a window (Hyprland-specific) |
| Alt+Tab, Super+Tab (+Shift) | Switch windows |
| Super+Page Up/Down, Ctrl+Alt+Left/Right | Previous/next workspace |
| Super+Shift+Page Up/Down | Move window to previous/next workspace |
| Super+1…9 / Super+Shift+1…9 | Go to / move window to workspace N |
| Super+drag / Super+right-drag | Move / resize window |

The top bar's network, Bluetooth and volume items open the matching GNOME
Settings panel. The screen locks after 5 minutes idle and turns off 30 seconds
later. Customise it all in `home/desktop/hyprland.nix`; Hyprland's Lua API is
documented at <https://wiki.hypr.land/>.

## Utilities

Standalone helper scripts that aren't part of the system configuration live in
`utils/`. Run them with `bash utils/<script>`.

| Script | Purpose |
| --- | --- |
| `factorio-setup-symlinks.sh` | For a standalone Factorio install in `~/factorio`: replaces its `config`, `mods`, `saves` and player-data files with symlinks into `~/.factorio`, so the data survives reinstalling the game. It deletes the existing copies in `~/factorio`, so move anything you want to keep into `~/.factorio` first. The standalone build is a generic Linux binary; on NixOS run it with `steam-run ~/factorio/bin/x64/factorio`. |

## Problems

- Waybar workspace buttons can't be clicked. Waybar 0.15 switches
  workspaces with pre-Lua `hyprctl dispatch` syntax, which Hyprland 0.55
  rejects when its config is in Lua. The buttons show workspaces; switch with
  the keyboard.
- Having a dedicated gpu and iGPU sometimes confuses hyprland. If this happens, either
  disable the iGPU or point Hyprland at the right card

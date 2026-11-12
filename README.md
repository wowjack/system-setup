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
| Restore a file from a /home snapshot                        | `snapper -c home list`, then copy it out of `/home/.snapshots/<number>/snapshot/`                  |
| Free disk space now                                         | `nh clean all --keep-since 14d --keep 5 --keep-one` (also runs weekly)                            |
| Run all checks                                              | `nix flake check`                                                                                 |
| Format the Nix files                                        | `nix fmt`                                                                                         |
| Development shell (formatter, linters, Nix language server) | `nix develop`, or `direnv allow` once                                                             |

`nh os` builds unprivileged and uses sudo only to activate the result, so Nix never
reads this repository as root. Before switching, it shows which packages will
be added, removed or upgraded. Flakes only see files tracked by git: `git add`
new files before rebuilding.

## Installing on a new machine

The disk layout (btrfs subvolumes, swapfile) is created by
[disko](https://github.com/nix-community/disko) from `hosts/nixos/disko.nix`,
so install from a terminal in the live session instead of the graphical
installer. **This erases the chosen disk.** Back up anything on it first.

1. Boot the NixOS 26.05 graphical ISO, connect to the network, and open a
   terminal. Don't start the graphical installer.
2. Get this repository:

   ```sh
   nix-shell -p git gh   # gh only if the repository is private: run `gh auth login`
   git clone https://github.com/wowjack/system-setup.git
   cd system-setup
   ```

3. Find the disk to install on. Use its stable name from `/dev/disk/by-id/`
   (e.g. `nvme-Samsung_SSD_990_EVO_Plus_1TB_…`, not one ending in `-partN`):

   ```sh
   lsblk -o NAME,SIZE,MODEL
   ls -l /dev/disk/by-id/
   ```

4. Partition, format and mount it at `/mnt`. disko asks for confirmation
   before erasing.

   ```sh
   nix --extra-experimental-features "nix-command flakes" build .#disko
   sudo ./result/bin/disko --mode destroy,format,mount \
     --argstr device /dev/disk/by-id/<disk> hosts/nixos/disko.nix
   rm result
   ```

5. Generate the hardware configuration for this machine (kernel modules, CPU
   microcode). `--no-filesystems` because disko already describes them. Until
   this file exists and is tracked by git, the flake deliberately has no
   `nixos` configuration.

   ```sh
   sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
     > hosts/nixos/hardware-configuration.nix
   git add hosts/nixos/hardware-configuration.nix
   ```

6. Copy the repository into the new system and install it. Root gets no
   password; you use `sudo` as `user`.

   ```sh
   sudo mkdir -p /mnt/home/user/repos
   sudo cp -r . /mnt/home/user/repos/system-setup
   sudo nixos-install --flake /mnt/home/user/repos/system-setup#nixos --no-root-passwd
   ```

7. Set `user`'s password and give it its home directory:

   ```sh
   sudo nixos-enter --root /mnt -c 'passwd user && chown -R user:users /home/user'
   ```

8. Reboot into the new system and commit `hosts/nixos/hardware-configuration.nix`
   (it contains no secrets).

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
| Storage        | `hosts/nixos/disko.nix`, `modules/nixos/storage.nix` | btrfs subvolumes (zstd compression, noatime), zram + 8 GB swapfile, monthly scrub, hourly/daily snapper snapshots of /home |
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

## Impermanence (planned)

The disk layout is already prepared for wiping `/` on every boot. See
"Impermanence later" in [ARCHITECTURE.md](ARCHITECTURE.md) for what's in
place and the remaining steps.

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

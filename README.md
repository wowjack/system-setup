Dotfiles and stuff for my machines: NixOS 26.05 for the system and
Home Manager for my user. Each machine (host) has a directory under `hosts/`
and is listed in `hosts` in `flake.nix`; everything else is shared.

| Host | Machine |
| --- | --- |
| `desktop` | my desktop workstation |

## Everyday commands

The `nh os` commands work from any directory & use this repository at
`~/repos/system-setup`. They build the configuration named after the machine's
hostname (`nixosConfigurations.<host>`); pass `-H <host>` to pick another, e.g.
for the first switch after a host is renamed.

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
| Turn a WireGuard VPN profile on / off                       | `nmcli connection up <name>` / `nmcli connection down <name>`                                     |
| Change a secret (password, SSH key, VPN profile)            | see [Secrets](#secrets)                                                                           |
| Free disk space now                                         | `nh clean all --keep-since 14d --keep 5 --keep-one` (also runs weekly)                            |
| Run all checks                                              | `nix flake check`                                                                                 |
| Build one check (e.g. evaluate one host)                    | `nix build .#checks.x86_64-linux.<check>`, e.g. `nixos-eval-desktop`                              |
| Format the Nix files                                        | `nix fmt`                                                                                         |
| Development shell (formatter, linters, Nix language server, sops) | `nix develop`, or `direnv allow` once                                                        |

`nh os` builds unprivileged and uses sudo only to activate the result, so Nix never
reads this repository as root. Before switching, it shows which packages will
be added, removed or upgraded. Flakes only see files tracked by git: `git add`
new files before rebuilding.

## Installing on a new machine

The disk layout (btrfs subvolumes, swapfile) is created by
[disko](https://github.com/nix-community/disko) from `hosts/<host>/disko.nix`,
so install from a terminal in the live session instead of the graphical
installer. **This erases the chosen disk.** Back up anything on it first.

Below, `<host>` is the machine's name in this repository (e.g. `desktop`). To
reinstall an existing host, start at step 1. A new machine needs a host first.

### Adding a host

Do this on a machine that already runs this configuration (so `nix flake check`
can check it), then push it:

1. Copy an existing host: `cp -r hosts/desktop hosts/<host>`, then
   `rm hosts/<host>/hardware-configuration.nix` (it is generated for each
   machine in step 6 below).
2. In `hosts/<host>/default.nix`, set `networking.hostName = "<host>";` (it must
   match the directory name; `checks.nixos-eval-<host>` enforces this) and
   adjust the timezone. Set `system.stateVersion` to the NixOS release you
   install with. Adjust `hosts/<host>/disko.nix` if the machine needs a
   different disk layout (e.g. swapfile size).
3. Add `"<host>"` to `hosts` in `flake.nix`.
4. `git add hosts/<host>`, run `nix flake check`, commit and push.

Until its hardware file exists, the host has no `nixosConfigurations` entry;
`checks.nixos-eval-<host>` evaluates it against stub hardware instead.

### Installing

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
     --argstr device /dev/disk/by-id/<disk> hosts/<host>/disko.nix
   rm result
   ```

5. Put the master key for the secrets on the new system (see
   [Secrets](#secrets)). Without it, `user`'s password stays locked and you
   can't log in. Open the Bitwarden web vault in Firefox, copy the key from
   its note, then:

   ```sh
   sudo install -d -m 700 /mnt/persist/sops/age
   sudo sh -c 'umask 077; cat > /mnt/persist/sops/age/keys.txt'
   ```

   Paste the key (Ctrl+Shift+V), press Enter, then Ctrl+D. Typing the
   `AGE-SECRET-KEY-1…` line by hand works too. Check it: this must print the
   `age1…` public key in `.sops.yaml`.

   ```sh
   sudo cat /mnt/persist/sops/age/keys.txt | nix-shell -p age --run 'age-keygen -y'
   ```

6. Generate the hardware configuration for this machine (kernel modules, CPU
   microcode). `--no-filesystems` because disko already describes them. Until
   this file exists and is tracked by git, the flake deliberately has no
   configuration for the host. Reinstalling an existing host replaces its file.

   ```sh
   sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
     > hosts/<host>/hardware-configuration.nix
   git add hosts/<host>/hardware-configuration.nix
   ```

7. Copy the repository into the new system and install it. Root gets no
   password; you use `sudo` as `user`. The new system can only decrypt its
   secrets, your password included, if the key from step 5 is right.

   ```sh
   sudo mkdir -p /mnt/home/user/repos
   sudo cp -r . /mnt/home/user/repos/system-setup
   sudo nixos-install --flake /mnt/home/user/repos/system-setup#<host> --no-root-passwd
   ```

8. Give `user` its home directory (the password comes from the secrets):

   ```sh
   sudo nixos-enter --root /mnt -c 'chown -R user:users /home/user'
   ```

9. Reboot into the new system, then commit and push
   `hosts/<host>/hardware-configuration.nix` (it contains no secrets).

### Finishing checklist

- Clone `obsidian_notes` and open `obsidian_notes/notes` as the vault in Obsidian.
- In VS Code, install the *direnv* extension (`mkhl.direnv`) so the editor
  sees each project's devShell.

## Secrets

Secrets are stored encrypted in this public repository with
[sops](https://github.com/getsops/sops) and decrypted on each machine by
[sops-nix](https://github.com/Mic92/sops-nix), on boot and on every switch.

| File | Contents |
| --- | --- |
| `secrets/secrets.yaml` | `user_password_hash` (login password), `ssh_id_ed25519` and `ssh_id_ed25519_pub` (SSH key pair, linked into `~/.ssh`) |
| `secrets/wireguard/<name>.conf` | One WireGuard VPN profile each, as downloaded from ProtonVPN (none yet; the folder is created with the first). Loaded into NetworkManager as profile `<name>`; never connects on its own. |
| `.sops.yaml` | The master key's public half. Anyone can encrypt with it; only the master key decrypts. |

**The master key** is a single age key (`AGE-SECRET-KEY-1…`). It is never in
this repository. It's kept in Bitwarden (secure note "system-setup sops master
key") and on each machine at `/persist/sops/age/keys.txt`, readable only by
root. Without it nothing can be decrypted, and because the password is a secret
too, **`user`'s password is locked: you can't log in**. If the Bitwarden note is
lost and no machine still has the key, the secrets are gone for good.

The commands below run from this repository with the development shell active
(`direnv allow` once), which provides `sops`, `age-keygen` and `mkpasswd`.
Editing needs the master key, so it runs as root. `TMPDIR=/dev/shm` keeps sops'
temporary plaintext copy in RAM.

| Task | Command |
| --- | --- |
| Edit `secrets/secrets.yaml` | `sudo env SOPS_AGE_KEY_FILE=/persist/sops/age/keys.txt TMPDIR=/dev/shm EDITOR=nano "$(command -v sops)" secrets/secrets.yaml` |
| Change the password | `mkpasswd -m yescrypt`, then edit `secrets/secrets.yaml` and replace `user_password_hash` with the output. `passwd` doesn't work: the configuration resets it. |
| Replace the SSH key | Edit `secrets/secrets.yaml` and paste the new keys into `ssh_id_ed25519` / `ssh_id_ed25519_pub`, each line indented by two spaces. |
| Add or replace a VPN profile (no master key needed) | `mkdir -p secrets/wireguard && sops encrypt --filename-override secrets/wireguard/<name>.conf <downloaded>.conf > secrets/wireguard/<name>.conf`, then delete the download. `<name>` is 1–15 characters of `a-z`, `0-9` and `-`. |
| Remove a VPN profile | `git rm secrets/wireguard/<name>.conf` (it is unloaded on the next switch) |
| Show a VPN profile | `sudo env SOPS_AGE_KEY_FILE=/persist/sops/age/keys.txt "$(command -v sops)" decrypt secrets/wireguard/<name>.conf` |

After any change: `git add` it, `nh os switch`, commit and push. Other machines
pick it up with `git pull` and `nh os switch`. `nh os switch` (and
`nix flake check`) refuses to build if any file under `secrets/` isn't
sops-encrypted, so a plaintext file is caught before it is committed.

A VPN profile's key may only be connected from one machine at a time (the
server would drop one of them). While connected, all internet traffic goes
through the VPN, and DNS lookups go only to the profile's DNS servers. The
local network (printers, the router) is still reached directly, but names
that only the router's DNS knows don't resolve until you disconnect. `nmcli connection modify --temporary <name> <setting> <value>` changes a
profile until the next reboot or until profiles are reloaded by a switch that
changes them.

### Putting the master key on a machine

When installing, follow step 5 of [Installing](#installing-on-a-new-machine).
On an installed machine whose key is missing (deleted, or a reset), while you
are still logged in:

```sh
sudo install -d -m 700 /persist/sops/age
sudo sh -c 'umask 077; cat > /persist/sops/age/keys.txt'   # paste, Enter, Ctrl+D
sudo cat /persist/sops/age/keys.txt | age-keygen -y        # must print the age1… key in .sops.yaml
nh os switch
```

If you can no longer log in, boot a NixOS live USB, open Bitwarden's web vault
in Firefox and copy the key, then:

```sh
sudo mount -o subvol=/persist /dev/disk/by-partlabel/disk-main-root /mnt
sudo install -d -m 700 /mnt/sops/age
sudo sh -c 'umask 077; cat > /mnt/sops/age/keys.txt'       # paste, Enter, Ctrl+D
sudo umount /mnt
```

and reboot.

### Replacing the master key

Do this if the key may have leaked, or to retire it. Updating the secrets
requires the old key, so do it on a machine that has it.

1. Make a new key in RAM and save the file's contents to Bitwarden in place of
   the old note: `age-keygen -o /dev/shm/new-key.txt` (prints its public key).
2. Put the new public key on the `age:` line of `.sops.yaml`.
3. Re-encrypt every file to the new key, with a new data key (`rotate`):

   ```sh
   for f in secrets/secrets.yaml secrets/wireguard/*.conf; do
     sudo env SOPS_AGE_KEY_FILE=/persist/sops/age/keys.txt "$(command -v sops)" updatekeys -y "$f"
     SOPS_AGE_KEY_FILE=/dev/shm/new-key.txt sops rotate -i "$f"
   done
   ```

4. On every machine, replace `/persist/sops/age/keys.txt` with the new key
   (as in [Putting the master key on a machine](#putting-the-master-key-on-a-machine))
   before switching to the new files. Then `rm /dev/shm/new-key.txt`, commit,
   push, and `nh os switch` everywhere.
5. If the old key leaked, also replace the secrets themselves: the old
   encrypted files stay in the public git history and the old key still
   opens them. Change the password, make a new SSH key (and replace it on
   GitHub and servers), and revoke the WireGuard configurations in your Proton
   account and download new ones.

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
| Secrets        | `modules/nixos/secrets.nix`, `modules/nixos/wireguard/`, `home/ssh.nix` | sops-nix: login password, SSH key pair, WireGuard VPN profiles (see [Secrets](#secrets))                               |
| Storage        | `hosts/<host>/disko.nix`, `modules/nixos/storage.nix` | btrfs subvolumes (zstd compression, noatime), zram + 8 GB swapfile, monthly scrub, hourly/daily snapper snapshots of /home |
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
| `factorio-setup-symlinks.sh` | For a standalone Factorio install in `~/factorio`: moves its `config`, `mods`, `saves` and player-data files into `~/.factorio` and leaves symlinks in their place, so the data survives reinstalling the game. Run it again after a reinstall to link the kept data into the new install. It never deletes anything: if an item exists in both places (or is a symlink to somewhere else), it lists it and exits before changing anything; keep one copy and run it again. The standalone build is a generic Linux binary; on NixOS run it with `steam-run ~/factorio/bin/x64/factorio`. |

## Problems

- Waybar workspace buttons can't be clicked. Waybar 0.15 switches
  workspaces with pre-Lua `hyprctl dispatch` syntax, which Hyprland 0.55
  rejects when its config is in Lua. The buttons show workspaces; switch with
  the keyboard.
- Having a dedicated gpu and iGPU sometimes confuses hyprland. If this happens, either
  disable the iGPU or point Hyprland at the right card
- Releasing Super after Super+scroll or Super+click sometimes opens the
  launcher as if Super had been tapped (Super+<key> doesn't). It happened in 1
  of 3 runs of a VM test that pressed real keys; the cause wasn't found, and
  the Hyprland session is unfinished for now.
- VS Code is held at 1.119.0 (`home/packages.nix`). The pinned nixpkgs has
  1.144.0, which fails to build
  ([nixpkgs#584492](https://github.com/NixOS/nixpkgs/issues/584492)); upstream
  has reverted it, but the revert hasn't reached the `nixos-26.05` channel yet.
  Once `nix flake update` brings it in, the build stops with a reminder to
  delete the workaround.

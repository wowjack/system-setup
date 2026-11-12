# Security

Security-relevant parts of this configuration and their risks.

## Secrets never go in this repository

Everything Nix evaluates ends up in `/nix/store`, which every user on the
machine can read. That includes file contents, settings and strings. Keep
secrets as ordinary mutable state outside this repository:

- SSH keys stay in `~/.ssh` (created with `ssh-keygen`).
- WireGuard/VPN profiles imported through NetworkManager are stored root-only in
  `/etc/NetworkManager/system-connections`.
- User passwords are set with `passwd`. `users.mutableUsers` stays at its
  default, so no password hashes are in the config.

If secrets ever need to be declarative, use an encryption tool built for it
(sops-nix or agenix) rather than plain Nix values.

## Privileged access

| Grant | Where | Risk |
| --- | --- | --- |
| `wheel` group | `modules/nixos/users.nix` | Full root via sudo (with password). |
| `libvirtd` group | `modules/nixos/users.nix` | Manages system VMs without a password, including passing host devices and storage to them. Close to root-equivalent. |
| `networkmanager` group | `modules/nixos/users.nix` | Changes network connections without a password. |
| Rootless Docker | `modules/nixos/virtualisation.nix` | Containers run with your user's privileges. Deliberately *not* the `docker` group, which is root-equivalent. |
| `Hyprland` security wrapper with `cap_sys_nice` | NixOS `programs.hyprland` | Lets the compositor raise its own scheduling priority. |
| Steam | `modules/nixos/gaming.nix` | Installs udev rules giving the logged-in user access to game controllers. Opens no firewall ports (Remote Play and the dedicated-server options are off). |

The NixOS firewall is on. The only open port is UDP 5353 (mDNS). The GNOME
module enables Avahi so the machine and others on the LAN (printers,
Chromecasts, file shares) can be discovered. To turn it off, set
`services.avahi.enable = false;` in `modules/nixos/desktop.nix`.

## Disk

- **No encryption.** The disk is not encrypted (a deliberate choice), so
  anyone with physical access to the disk or machine can read all data on it,
  including `/home` and saved Wi-Fi/VPN credentials.
- **Snapshots keep deleted files.** snapper snapshots `/home` hourly and daily,
  so a deleted or overwritten file stays readable in `/home/.snapshots` for up
  to 7 days. To remove something sensitive for good, also delete the snapshots
  that contain it (`snapper -c home delete <number>`). `user` may manage
  these snapshots without sudo (`ALLOW_USERS`).

## Proprietary software and loss of Flatpak sandboxing

`modules/nixos/nix.nix` lists every unfree package explicitly. A new
proprietary package fails evaluation until it is added there.

The Debian setup ran apps as Flatpaks. Here they come from nixpkgs and run
unsandboxed with full access to your home directory and session. That applies
to Discord, Slack, Zoom, Steam, Obsidian, VS Code and the rest. VS Code is the
FHS variant, so its extensions can download and run native binaries, as on
other distros. Treat extensions and apps with the same trust as any program you
run.

## Supply chain

- `flake.lock` pins nixpkgs and Home Manager to exact revisions. Nothing
  changes until `nix flake update` is run and the lock file is committed.
- The wallpaper is downloaded from a commit-pinned GitHub URL and checked
  against a fixed hash (`home/desktop/shared.nix`).
- The nix-index database (for comma and command-not-found) is a prebuilt file
  from nix-community/nix-index-database's GitHub releases. Its URL and hash are
  pinned by `flake.lock`. It only maps commands to package names; the programs
  comma runs come from nixpkgs. comma asks which package to use when several
  provide a command.
- Binaries come from cache.nixos.org, signed by the NixOS infrastructure.
  Unfree packages are fetched from their vendors' URLs and hash-checked by
  nixpkgs.

## Screen locking

GNOME locks the screen itself. In the Hyprland session, hypridle locks with
hyprlock after 5 minutes idle and before suspend. Hyprlock authenticates through
the `hyprlock` PAM service (`modules/nixos/desktop.nix`). Without that service,
hyprlock could not unlock. The hypridle and lock services only run under
Hyprland, so a broken Hyprland helper cannot affect GNOME's locking.

## Rollback window

Old generations stay bootable until the weekly `nh clean all` removes those
older than 14 days. It always keeps at least the 5 most recent. An insecure or
broken change can be undone from the boot menu or with `nh os rollback` while
its predecessor still exists.

# Security

Security-relevant parts of this configuration and their risks.

## Secrets

Everything Nix evaluates ends up in `/nix/store`, which every user on the
machine can read. Secrets therefore never appear as plain Nix values. They are
stored sops-encrypted in `secrets/` (age encryption, one master key) and
decrypted on the machine by sops-nix (README.md, "Secrets").

- **The master key opens everything.** Every secret, on every machine, is
  encrypted to the one age key in Bitwarden. Whoever has it can read all of
  them, including the copies in the public git history forever. Replacing the
  key (README.md) protects future versions only; after a leak, the secrets
  themselves have to be changed.
- **Where the key is on disk.** `/persist/sops/age/keys.txt`, root-only. The
  disk is not encrypted (see [Disk](#disk)), so physical access to any one
  machine gives the key, and with it the secrets of all machines.
- **Losing the key locks you out.** The login password is one of the secrets:
  without the key it can't be decrypted, NixOS locks the account, and nobody
  can log in. Keep the Bitwarden note safe.
- **What is public.** The encrypted files reveal the secrets' names (keys in
  `secrets.yaml`, VPN profile file names), their approximate sizes, when they
  changed, and the master public key. Values are encrypted.
- **Plaintext is refused.** The system build and `nix flake check` fail if any
  file under `secrets/` isn't sops-encrypted (`modules/nixos/secrets.nix`), so
  a decrypted or never-encrypted file is caught by `nh os switch` before it is
  committed. Nothing stops a commit made without building first.
- **VPN DNS.** While a VPN profile is connected, only its DNS servers are used,
  so lookups can't fall back to the router's DNS server outside the tunnel.
  Traffic to the local network itself still bypasses the tunnel.
- **Decrypted copies.** sops-nix writes secrets to `/run/secrets`, which is
  `ramfs`: never written to disk, not even to swap. Owners: the password hash
  root-only, the SSH keys `user` (private key mode 0400). WireGuard profiles
  are converted into NetworkManager profiles in
  `/run/NetworkManager/system-connections` (root-only, mode 0600). That is a
  `tmpfs`, which the kernel may move to swap, and the swapfile is on the
  unencrypted disk. (A profile imported the usual way would be stored on disk
  in `/etc`.)
- **The SSH private key has no passphrase.** Any program running as `user`
  can read and use it, as before.
- **Editing.** sops writes a temporary plaintext copy while editing; the
  documented commands put it in `/dev/shm` (RAM). The one-time setup put the
  master key in `/dev/shm` too, never on disk.
- **Users are fixed by the configuration** (`users.mutableUsers = false`).
  `passwd` changes are overwritten on the next switch; root has no password.

## Privileged access

| Grant | Where | Risk |
| --- | --- | --- |
| `wheel` group | `modules/nixos/users.nix` | Full root via sudo (with password), and with it the master key. |
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
- **No boot-menu editor.** systemd-boot's kernel-parameter editor is off
  (`hosts/nixos/default.nix`), so the boot menu can't be used for a passwordless
  root shell (`init=/bin/sh`). With an unencrypted disk this only adds
  protection together with a firmware password and a locked boot order;
  otherwise booting from a USB stick gives the same access.
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
- sops-nix is pinned by `flake.lock` like the other inputs. It runs as root
  at boot and on every switch, with access to the master key.
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

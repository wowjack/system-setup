# Architecture

This repository is a Nix flake whose main output is one NixOS system,
`nixosConfigurations.nixos`. `nixos-rebuild` evaluates it into a single
immutable system closure in `/nix/store` and activates it. Nothing is installed
imperatively. Every rebuild produces a new generation, and older generations
remain bootable until garbage-collected.

```
flake.nix ── inputs (pinned in flake.lock): nixpkgs nixos-26.05, home-manager release-26.05,
 │            nix-index-database (prebuilt package index), disko (disk partitioning);
 │            all follow the same nixpkgs
 │
 ├─ nixosConfigurations.nixos = nixosSystem [
 │     home-manager.nixosModules.home-manager
 │     nix-index-database.nixosModules.nix-index
 │     disko.nixosModules.disko
 │     hosts/nixos/default.nix ──────── machine: hostname, bootloader, locale, stateVersion
 │       ├─ disko.nix ───────────────── disk layout: ESP + btrfs subvolumes
 │       └─ modules/nixos/ ──────────── system (root-owned) configuration
 │            ├─ nix.nix               flakes, nh (rebuilds, cleanup), comma, store optimisation, unfree allowlist
 │            ├─ storage.nix           zram swap, btrfs scrub, snapper snapshots of /home
 │            ├─ desktop.nix           GDM + GNOME + Hyprland, hyprlock PAM, audio, network, bluetooth
 │            ├─ virtualisation.nix    rootless Docker, libvirt, virt-manager
 │            ├─ gaming.nix            Steam
 │            └─ users.nix             user `user`, Home Manager wiring ──┐
 │     hosts/nixos/hardware-configuration.nix (generated on the machine)  │
 │   ]                                                                    │
 │                                                                        ▼
 │   home/ ───────────────────────────────────── Home Manager config for `user`
 │     ├─ shell.nix                bash, direnv + nix-direnv
 │     ├─ git.nix                  git identity and defaults
 │     ├─ packages.nix             user applications and CLI tools
 │     └─ desktop/
 │          ├─ shared.nix          preferences used by both sessions (data, not a module)
 │          ├─ default.nix         monospace font
 │          ├─ gnome.nix           dconf settings
 │          └─ hyprland.nix        Hyprland config + session helpers
 │
 ├─ checks.x86_64-linux ── checks/ (run by `nix flake check`; see TESTING.md)
 ├─ packages.disko ─────── the disko CLI at the pinned version, used when installing
 ├─ formatter ──────────── nixfmt-tree (`nix fmt`)
 └─ devShells.default ──── formatter, linters, Nix language server (`nix develop` / direnv)
```

## Components

### Flake (`flake.nix`, `flake.lock`)

Declares the inputs and wires the modules together. `nixpkgs` and
`home-manager` follow the same release, and Home Manager uses the system's
nixpkgs instance (`useGlobalPkgs`), so there is one package set and one unfree
allowlist. `flake.lock` pins exact revisions. Packages change only when
`nix flake update` is run and the new lock file is committed.

`nixosConfigurations.nixos` is defined only once
`hosts/nixos/hardware-configuration.nix` exists and is tracked by git. That file
comes from `nixos-generate-config` on the real machine. Without this guard, a
system could be built against made-up disks.

### Host (`hosts/nixos/`)

Settings that belong to this particular machine: hostname, bootloader,
timezone, locale, `system.stateVersion`, the disk layout, and the generated
hardware configuration (created with `--no-filesystems`, because disko defines
the filesystems). A second machine would get its own directory here and reuse
`modules/nixos`.

### Disk layout (`hosts/nixos/disko.nix`, `modules/nixos/storage.nix`)

One GPT disk. A 1 GB EFI system partition holds `/boot` (systemd-boot). The
rest is one btrfs filesystem split into subvolumes, all mounted with
`compress=zstd,noatime` except the swap subvolume:

| Subvolume | Mounted at | Holds |
| --- | --- | --- |
| `/root` | `/` | the system root: everything not listed below |
| `/home` | `/home` | user data; `/home/.snapshots` (nested) holds snapper's snapshots |
| `/nix` | `/nix` | the Nix store |
| `/persist` | `/persist` | empty, reserved for impermanence |
| `/log` | `/var/log` | system logs |
| `/swap` | `/swap` | an 8 GB swapfile |

The same file serves the installer and the running system. At install time the
disko CLI is given the target disk (`--argstr device …`) and creates the layout.
The NixOS configuration imports the file to generate `fileSystems` and
`swapDevices`. Those refer to partitions by GPT label (`disk-main-ESP`,
`disk-main-root`), so the configuration doesn't record or depend on which disk
was chosen.

`storage.nix` adds zram swap (compressed RAM, up to half of it, used before the
swapfile), a monthly `btrfs scrub`, and snapper's timeline for `/home`: hourly
snapshots kept 24 hours and daily ones kept 7 days.

#### Impermanence later

Impermanence recreates `/` empty on every boot and keeps only declared state.
What's already in place: `/` is its own subvolume, separate from `/nix`,
`/home`, `/persist` and `/var/log`, so it can be discarded without touching
them. The remaining steps:

1. Add the [impermanence](https://github.com/nix-community/impermanence)
   flake input and module.
2. Add an initrd step that, on every boot, moves the `/root` subvolume aside
   (keeping recent ones for a while) and creates a fresh empty one. The btrfs
   filesystem is `/dev/disk/by-partlabel/disk-main-root`.
3. Mark `/persist` and `/var/log` `neededForBoot = true`.
4. Declare the state to keep under `/persist`. Typical candidates are
   `/etc/machine-id`, `/var/lib/nixos` (user/group IDs), `/var/lib/systemd`,
   `/etc/NetworkManager/system-connections`, `/var/lib/bluetooth` and
   `/var/lib/libvirt`.
5. Passwords: with `users.mutableUsers`, they live in `/etc/shadow`, which would
   be wiped. Use `hashedPasswordFile` pointing into `/persist` instead.

Before switching, list what currently lives on `/` (for example with
`btrfs subvolume find-new`) to check nothing needed is missed.

### System modules (`modules/nixos/`)

Root-owned configuration, one file per concern. These are things that need
system integration: services, PAM, groups, udev rules, 32-bit graphics drivers.
Plain user applications go in `home/` instead.

### Home Manager (`home/`)

Everything that belongs to the user: applications, shell, git, desktop
settings. It runs as part of every system switch (the
`home-manager-user.service` unit). Packages go to `/etc/profiles/per-user/user`.
Dotfiles are symlinks into the store, and dconf values are loaded with
`dconf load`. Removing an entry removes the file, package or dconf key on the
next switch.

### Desktop sessions (`modules/nixos/desktop.nix`, `home/desktop/`)

GDM lists two Wayland sessions that share the same apps, dconf database,
GNOME keyring (unlocked by GDM's PAM stack) and PipeWire:

- **GNOME**: the stock session, customised only through dconf (`gnome.nix`).
- **Hyprland**: `hyprland.nix` generates `~/.config/hypr/hyprland.lua`
  (Hyprland 0.55's Lua config) with GNOME-like keybindings. GNOME Shell
  provides some things itself that Hyprland needs as separate programs: a bar
  (waybar), a launcher (fuzzel), notifications (mako), the wallpaper (swaybg),
  a polkit agent, idle handling (hypridle) and a lock screen (hyprlock). All of
  them run as systemd user services wanted by `hyprland-session.target`. Only
  Hyprland starts that target at login, so none of them ever run under GNOME.
  This is also why the NixOS `programs.hyprlock` module and Home Manager's
  D-Bus-activated `services.mako` are deliberately not used.

Preferences both sessions should agree on are defined once in
`home/desktop/shared.nix`: the wallpaper (fetched by URL with a pinned hash),
the monospace font, keyboard repeat, mouse acceleration and touchpad. They are
then translated into each session's format (for example, GNOME's key-repeat
interval in ms becomes Hyprland's repeat rate per second).

### Checks (`checks/`)

Derivations that `nix flake check` builds. They evaluate the system against
`checks/stub-hardware.nix`, validate the dconf settings and the Hyprland config,
and lint the repository. See TESTING.md.

### Utilities (`utils/`)

Standalone helper scripts that you run by hand. They are not part of the flake
and nothing in the system configuration uses them.

## Design decisions

- **Flakes + Home Manager as a NixOS module.** One command rebuilds system and
  user together, and both roll back together.
- **nixpkgs instead of Flatpak.** Apps are pinned by `flake.lock` and covered by
  rollbacks. The cost is Flatpak's sandbox (see SECURITY.md).
- **No global language toolchains.** Each project declares its tools in a
  devShell, and direnv + nix-direnv load it per directory. That keeps toolchain
  versions per project and out of the global environment.
- **Store hygiene.** A weekly `nh clean all` removes system and Home Manager
  generations older than 14 days (keeping at least 5), then garbage-collects.
  It also keeps every direnv project's current shell. On top of that: store
  optimisation, at most 10 boot entries, and no nix-channels.

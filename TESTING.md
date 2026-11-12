# Testing

## Running the checks

On NixOS (or any machine with Nix and flakes enabled), from the repository root:

```sh
nix flake check      # evaluate everything and build all checks
nix fmt              # format the Nix files (fixes what the lint check reports)
```

New files must be `git add`ed first: flakes ignore untracked files.
The system can only be evaluated once `secrets/secrets.yaml` exists (sops-nix
checks that the files it decrypts are present). `checks.disko-layout` and
`checks.secrets` boot VMs, so they need KVM (`/dev/kvm`). NixOS enables that
automatically on machines with hardware virtualisation.

On a machine without Nix (e.g. the old Debian install), run the checks in a
throwaway container. The repository is mounted read-only and copied, so its git
index is not touched. `--device /dev/kvm` and the `system-features` option let
the VM test run:

```sh
docker run --rm --device /dev/kvm -v "$PWD":/src:ro nixos/nix:2.35.4 sh -c '
  cp -r /src /work && cd /work &&
  git config --global --add safe.directory /work && git add -A &&
  nix --extra-experimental-features "nix-command flakes" --option sandbox false \
    --option system-features "kvm nixos-test big-parallel benchmark" flake check -L'
```

## What the checks cover

| Check | What it verifies |
| --- | --- |
| `nixosConfigurations.*` | `nix flake check` evaluates every defined system. `nixos` only exists once the machine's hardware file is committed (see README). |
| `checks.nixos-eval` | Evaluates the complete system (all NixOS and Home Manager modules, assertions, and every package's derivation) against `checks/stub-hardware.nix`, without building it. Catches option typos, type errors, removed or renamed options, and unfree packages missing from the allowlist. Also instantiates disko's partitioning script for `hosts/nixos/disko.nix`. Works before the real hardware file exists. |
| `checks.disko-layout` | VM test using disko's harness. Formats a virtual disk with `hosts/nixos/disko.nix` (and destroys and recreates it), boots a minimal system from it, then checks that every subvolume is mounted where expected with `compress=zstd,noatime`, that `/home/.snapshots` is a subvolume, and that the swapfile is active. The virtual disk is 4 GB, so the test shrinks the swapfile to 1 GB; everything else is the real layout. The test script stops the booted VM itself, because disko's harness doesn't register it with the current nixpkgs test driver and the build would otherwise hang after passing. |
| `checks.secrets` | VM test with throwaway secrets generated at build time (an age key, password hash, SSH key pair and WireGuard profile; nothing test-related is committed), encrypted like the real ones and decrypted with the key at `/persist/sops/age/keys.txt`. Checks that `user`'s password is the encrypted hash, that `~/.ssh` holds the SSH key pair with the private key owned by `user` and mode 0400 (and that `ssh-keygen` accepts it), and that the WireGuard profile is loaded root-only (0600), not autoconnecting and not connected. A second VM runs a WireGuard server whose endpoint is reached through the default gateway, like a provider's. `user` connects with `nmcli`, a ping crosses the tunnel and NixOS's (strict reverse-path) firewall, other traffic is routed into the tunnel, and disconnecting removes that route. Finally, a `nmcli --temporary` change is undone when the profiles reload, and nothing was written to `/etc/NetworkManager`. |
| `checks.wireguard-profile` | `modules/nixos/wireguard/nm_profile.py` turns a Proton-style profile (IPv4 + IPv6) into a NetworkManager profile with the expected addresses, DNS, peer, `autoconnect=false`, mode 0600 and the same UUID on every run, and fails on a file NetworkManager can't import. Runs without a VM. |
| `checks.dconf` | `checks/check_dconf.py` loads the GSettings schemas shipped by gsettings-desktop-schemas, GTK 3/4, Mutter and Nautilus. It then confirms every key in `home/desktop/gnome.nix` exists, parses to exactly the type the schema expects (e.g. `uint32` vs `int32`), and is within the allowed range or choices. dconf would otherwise ignore such mistakes silently. |
| `checks.hyprland-config` | Runs `Hyprland --verify-config` on the generated `hyprland.lua`. Catches Lua syntax errors, unknown config keys and invalid dispatcher arguments. |
| `checks.lint` | `nixfmt --check`, `statix` (anti-patterns; `statix.toml` disables only the repeated-keys rule), `deadnix` (unused code), and `ruff check` + `ruff format --check` on all Python files. |

Each check has been shown to fail on a deliberately broken input. These were
a uint32 key given as int32, an invalid enum value, a nonexistent key, an
invalid Hyprland dispatcher argument, a Lua syntax error, and a profile
converter that left autoconnect on (caught by both `wireguard-profile` and
`secrets`). The disk
layout test caught a real failure on its first run: an 8 GB swapfile that
didn't fit the test disk, which is why the test shrinks it. While writing the
secrets test, a manual run showed that turning off the profile's default route
(`ipv4.never-default`) stops all traffic through the tunnel, including from
apps bound to it, so that is not a usable "only some apps" mode.

## What is not covered

- **Building the full system.** `nixos-eval` instantiates every derivation but
  doesn't build or download them. `nh os build` does that on the real machine.
- **Runtime behaviour.** Booting, GDM sessions, Hyprland keybindings (e.g.
  tapping Super), the waybar layout and the idle/lock timing are not exercised.
  Try changes with `nh os test`: it activates the new configuration without
  creating a boot entry, so a reboot undoes it.
- **Real secrets and the real VPN.** The checks use throwaway secrets. Whether
  your master key decrypts the real files, and whether a Proton server accepts
  your profiles, is only known on the machine.
- **GUI for VPN profiles.** Whether GNOME Settings shows the profiles is not
  tested; `nmcli` is.
- **Hardware.** `hardware-configuration.nix` is machine-generated and only
  evaluated once it exists. The disk layout test boots a minimal system, not
  this configuration, on a virtual disk.

## Adding a check

Add an attribute to the set in `checks/default.nix`. It must be a derivation
that fails to build when the check fails. The module arguments give access to
the evaluated system (`nixos.config`) and to Home Manager's config for `user`
(`home`). Keep larger scripts in their own file under `checks/`. Python scripts
are linted by ruff as part of `checks.lint`.

## Development environment

`nix develop`, or `direnv allow` once to load it automatically (`.envrc`
contains `use flake`). It provides nixfmt/nixfmt-tree, statix, deadnix, ruff,
the `nil` Nix language server, and sops, age and mkpasswd for the secrets, at
the versions pinned by `flake.lock`.

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
index is not touched. `--device /dev/kvm` passes KVM in, and the `chmod` lets
Nix's build users open it. It changes only the container's own device node,
not the host's. Without it, QEMU silently falls back to software emulation,
which is so slow that the VM tests time out. The `system-features` option lets
the VM tests run at all:

```sh
docker run --rm --device /dev/kvm -v "$PWD":/src:ro nixos/nix:2.35.4 sh -c '
  chmod 666 /dev/kvm &&
  cp -r /src /work && cd /work &&
  git config --global --add safe.directory /work && git add -A &&
  nix --extra-experimental-features "nix-command flakes" --option sandbox false \
    --option system-features "kvm nixos-test big-parallel benchmark" flake check -L'
```

In the log, `failed to initialize kvm` from QEMU means the VMs ran without KVM.
Building as root instead (`--option build-users-group ""`) also gives QEMU
access, but without the sandbox some builds then fail Nix's purity check
(`/homeless-shelter exists`).

## What the checks cover

| Check | What it verifies |
| --- | --- |
| `nixosConfigurations.*` | `nix flake check` evaluates every defined system. A host's configuration only exists once its hardware file is committed (see README). |
| `checks.nixos-eval-<host>` | One per host in `hosts` (`flake.nix`). Evaluates the host's complete system (all NixOS and Home Manager modules, assertions, and every package's derivation) against `checks/stub-hardware.nix`, without building it. Catches option typos, type errors, removed or renamed options, and unfree packages missing from the allowlist. Also instantiates disko's partitioning script for `hosts/<host>/disko.nix`, both through the NixOS module and through disko's CLI exactly as the install command in README.md does (the CLI passes extra arguments to the file). Fails if the host's `networking.hostName` isn't its directory name (`nh os switch` picks the configuration by hostname). Works before the host's real hardware file exists. |
| `checks.disko-layout` | VM test using disko's harness. Formats a virtual disk with `hosts/desktop/disko.nix` (and destroys and recreates it), boots a minimal system from it, then checks that every subvolume is mounted where expected with `compress=zstd,noatime`, that `/home/.snapshots` is a subvolume, and that the swapfile is active. The virtual disk is 4 GB, so the test shrinks the swapfile to 1 GB; everything else is the real layout. The test script stops the booted VM itself, because disko's harness doesn't register it with the current nixpkgs test driver and the build would otherwise hang after passing. |
| `checks.secrets` | VM test with throwaway secrets generated at build time (an age key, password hash, SSH key pair and WireGuard profile; nothing test-related is committed), encrypted like the real ones and decrypted with the key at `/persist/sops/age/keys.txt`. Checks that `user`'s password is the encrypted hash, that `~/.ssh` holds the SSH key pair with the private key owned by `user` and mode 0400 (and that `ssh-keygen` accepts it), and that the WireGuard profile is loaded root-only (0600), not autoconnecting and not connected. A second VM runs a WireGuard server whose endpoint is reached through the default gateway, like a provider's. `user` connects with `nmcli`, a ping crosses the tunnel and NixOS's (strict reverse-path) firewall, other traffic is routed into the tunnel, and disconnecting removes that route. With a LAN connection that has its own DNS server, `/etc/resolv.conf` lists only the VPN's DNS server while connected, and the LAN's again afterwards. A `nmcli --temporary` change is undone when the profiles reload, and nothing was written to `/etc/NetworkManager`. Finally, switching to the same system without the profile (a specialisation) unloads it and deletes its file. |
| `checks.secrets-encrypted` | Every file under `secrets/` is sops-encrypted (`sops filestatus`). The same derivation is part of the system build (`system.checks`), so `nh os switch` refuses a plaintext file too. |
| `checks.wireguard-profile` | `modules/nixos/wireguard/nm_profile.py` turns a Proton-style profile (IPv4 + IPv6) into a NetworkManager profile with the expected addresses, DNS, `dns-priority=-50` (exclusive DNS) in both IP sections, peer, `autoconnect=false`, mode 0600 and the same UUID on every run. A profile without DNS servers gets no DNS priority. Fails on a file NetworkManager can't import. Runs without a VM. |
| `checks.dconf` | `checks/check_dconf.py` loads the GSettings schemas shipped by gsettings-desktop-schemas, GTK 3/4, Mutter and Nautilus. It then confirms every key in `home/desktop/gnome.nix` exists, parses to exactly the type the schema expects (e.g. `uint32` vs `int32`), and is within the allowed range or choices. dconf would otherwise ignore such mistakes silently. |
| `checks.hyprland-config` | Runs `Hyprland --verify-config` on the generated `hyprland.lua`. Catches Lua syntax errors, unknown config keys and invalid dispatcher arguments. |
| `checks.hyprland-session-services` | Every Home Manager user service started by `hyprland-session.target` is started by nothing else, so none of them can run in GNOME. |
| `checks.factorio-symlinks` | Runs `utils/factorio-setup-symlinks.sh` in a throwaway home directory: the first run moves the game's data to `~/.factorio` and links it back, a second run changes nothing, a reinstalled game gets linked, and data in both places or a symlink to elsewhere stops the script before anything changes. |
| `checks.lint` | `nixfmt --check`, `statix` (anti-patterns; `statix.toml` disables only the repeated-keys rule), `deadnix` (unused code), `ruff check` + `ruff format --check` on all Python files, and `shellcheck` on all shell scripts. The machine-generated `hosts/*/hardware-configuration.nix` files are excluded from the Nix linters. |

Each check has been shown to fail on a deliberately broken input. These were
a uint32 key given as int32, an invalid enum value, a nonexistent key, an
invalid Hyprland dispatcher argument, a Lua syntax error, and a profile
converter that left autoconnect on (caught by both `wireguard-profile` and
`secrets`). Later additions were checked against the bugs they guard against:
`hosts/desktop/disko.nix` taking only `{ device }` (`nixos-eval-desktop`), a plaintext
WireGuard profile and a decrypted `secrets.yaml` (`secrets-encrypted`), the
converter without DNS priority (`wireguard-profile`, and the DNS subtest of
`secrets`), the WireGuard service removed together with its last profile (the
last subtest of `secrets`), waybar without its `WantedBy` override
(`hyprland-session-services`), and the old delete-then-link Factorio script
(`factorio-symlinks`). `lint` was shown to pass with `nixos-generate-config`'s
real output as the hardware file. When hosts were introduced, `nixos-eval-desktop`
was shown to fail on a host whose `networking.hostName` didn't match its
directory, and a host without a hardware file was shown to get no
`nixosConfigurations` entry. At the same time, `deadnix` was found to have
checked nothing (its `--exclude` list swallowed the `.` after it); with that
fixed, it found an unused argument in `home/packages.nix`. The disk
layout test caught a real failure on its first run: an 8 GB swapfile that
didn't fit the test disk, which is why the test shrinks it. While writing the
secrets test, a manual run showed that turning off the profile's default route
(`ipv4.never-default`) stops all traffic through the tunnel, including from
apps bound to it, so that is not a usable "only some apps" mode.

## What is not covered

- **Building the full system.** `nixos-eval` instantiates every derivation but
  doesn't build or download them. `nh os build` does that on the real machine.
  Packages missing from the binary cache, such as the proprietary ones, are
  built locally at that point, so a broken one only shows up then (VS Code
  1.144.0 did; see README.md, "Problems").
- **Runtime behaviour.** Booting, GDM sessions, Hyprland keybindings (e.g.
  tapping Super; see README.md, "Problems"), the waybar layout and the
  idle/lock timing are not exercised.
  Try changes with `nh os test`: it activates the new configuration without
  creating a boot entry, so a reboot undoes it.
- **Real secrets and the real VPN.** The checks use throwaway secrets. Whether
  your master key decrypts the real files, and whether a Proton server accepts
  your profiles, is only known on the machine.
- **GUI for VPN profiles.** Whether GNOME Settings shows the profiles is not
  tested; `nmcli` is.
- **Hardware.** `hardware-configuration.nix` is machine-generated and only
  evaluated once it exists. The disk layout test boots a minimal system, not
  this configuration, on a virtual disk, and only tests `desktop`'s layout.
- **Other hosts' desktop settings.** `dconf`, `hyprland-config` and
  `hyprland-session-services` check the Home Manager configuration of
  `desktop` (`checks/default.nix`). That configuration is shared by every host
  that imports `modules/nixos`; a host that changes it needs its own checks.

## Adding a check

Add an attribute to the set in `checks/default.nix`. It must be a derivation
that fails to build when the check fails. The module arguments give access to
every host's evaluated system (`systems.<host>.config`), and the `let` block
names the desktop's (`nixos.config`) and its Home Manager config for `user`
(`home`). Keep larger scripts in their own file under `checks/`. Python scripts
are linted by ruff as part of `checks.lint`.

## Development environment

`nix develop`, or `direnv allow` once to load it automatically (`.envrc`
contains `use flake`). It provides nixfmt/nixfmt-tree, statix, deadnix, ruff,
the `nil` Nix language server, and sops, age and mkpasswd for the secrets, at
the versions pinned by `flake.lock`.

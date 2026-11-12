# Testing

## Running the checks

On NixOS (or any machine with Nix and flakes enabled), from the repository root:

```sh
nix flake check      # evaluate everything and build all checks
nix fmt              # format the Nix files (fixes what the lint check reports)
```

New files must be `git add`ed first: flakes ignore untracked files.

On a machine without Nix (e.g. the old Debian install), run the checks in a
throwaway container. The repository is mounted read-only and copied, so its git
index is not touched:

```sh
docker run --rm -v "$PWD":/src:ro nixos/nix:2.35.4 sh -c '
  cp -r /src /work && cd /work &&
  git config --global --add safe.directory /work && git add -A &&
  nix --extra-experimental-features "nix-command flakes" --option sandbox false flake check -L'
```

## What the checks cover

| Check | What it verifies |
| --- | --- |
| `nixosConfigurations.*` | `nix flake check` evaluates every defined system. `nixos` only exists once the machine's hardware file is committed (see README). |
| `checks.nixos-eval` | Evaluates the complete system (all NixOS and Home Manager modules, assertions, and every package's derivation) against `checks/stub-hardware.nix`, without building it. Catches option typos, type errors, removed or renamed options, and unfree packages missing from the allowlist. Works before the real hardware file exists. |
| `checks.dconf` | `checks/check_dconf.py` loads the GSettings schemas shipped by gsettings-desktop-schemas, GTK 3/4, Mutter and Nautilus. It then confirms every key in `home/desktop/gnome.nix` exists, parses to exactly the type the schema expects (e.g. `uint32` vs `int32`), and is within the allowed range or choices. dconf would otherwise ignore such mistakes silently. |
| `checks.hyprland-config` | Runs `Hyprland --verify-config` on the generated `hyprland.lua`. Catches Lua syntax errors, unknown config keys and invalid dispatcher arguments. |
| `checks.lint` | `nixfmt --check`, `statix` (anti-patterns; `statix.toml` disables only the repeated-keys rule), `deadnix` (unused code), and `ruff check` + `ruff format --check` on the Python check script. |

Each check has been shown to fail on a deliberately broken input. These were
a uint32 key given as int32, an invalid enum value, a nonexistent key, an
invalid Hyprland dispatcher argument, and a Lua syntax error.

## What is not covered

- **Building the full system.** `nixos-eval` instantiates every derivation but
  doesn't build or download them. `nh os build` does that on the real machine.
- **Runtime behaviour.** Booting, GDM sessions, Hyprland keybindings (e.g.
  tapping Super), the waybar layout and the idle/lock timing are not exercised.
  Try changes with `nh os test`: it activates the new configuration without
  creating a boot entry, so a reboot undoes it.
- **Hardware.** `hardware-configuration.nix` is machine-generated and only
  evaluated once it exists.

## Adding a check

Add an attribute to the set in `checks/default.nix`. It must be a derivation
that fails to build when the check fails. The module arguments give access to
the evaluated system (`nixos.config`) and to Home Manager's config for `user`
(`home`). Keep larger scripts in their own file under `checks/`. Python scripts
are linted by ruff as part of `checks.lint`.

## Development environment

`nix develop`, or `direnv allow` once to load it automatically (`.envrc`
contains `use flake`). It provides nixfmt/nixfmt-tree, statix, deadnix, ruff and
the `nil` Nix language server, at the versions pinned by `flake.lock`.

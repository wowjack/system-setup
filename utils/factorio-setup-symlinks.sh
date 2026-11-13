#!/usr/bin/env bash
# For a standalone Factorio install in ~/factorio: moves its player data
# (config, mods, saves, ...) into ~/.factorio and leaves symlinks in its place,
# so the data survives deleting and reinstalling the game. Safe to run again,
# e.g. after reinstalling: items that are already linked are left alone.
#
# Nothing is deleted. If an item exists in both places, or is a symlink that
# points somewhere else, the script lists it and exits before changing anything.
set -euo pipefail

FACTORIO="$HOME/factorio"
DATA="$HOME/.factorio"

DIRS=(config mods saves)
FILES=(blueprint-storage-2.dat player-data.json achievements-modded.dat)

if [[ ! -d "$FACTORIO" ]]; then
    echo "No Factorio install at $FACTORIO." >&2
    exit 1
fi

# Check everything first, so a problem never leaves a half-done migration.
problems=()
for name in "${DIRS[@]}" "${FILES[@]}"; do
    game="$FACTORIO/$name"
    data="$DATA/$name"
    if [[ -L "$game" ]]; then
        if [[ "$(readlink "$game")" != "$data" ]]; then
            problems+=("$game is a symlink to $(readlink "$game"), not to $data")
        fi
    elif [[ -e "$game" && ( -e "$data" || -L "$data" ) ]]; then
        problems+=("$name exists in both $FACTORIO and $DATA")
    fi
done
if (( ${#problems[@]} > 0 )); then
    echo "Nothing was changed:" >&2
    printf '  %s\n' "${problems[@]}" >&2
    echo "Keep one copy of each (in $DATA) and run this again." >&2
    exit 1
fi

mkdir -p "$DATA"

# Moves $FACTORIO/$1 into $DATA (unless already linked) and links it back.
# $2 is "dir" or "file": a directory that exists in neither place is created
# in $DATA so the game can use it; a missing file is linked anyway, and
# Factorio creates it on first use.
move_and_link() {
    local name="$1" kind="$2"
    local game="$FACTORIO/$name" data="$DATA/$name"

    if [[ -L "$game" ]]; then
        if [[ "$kind" == dir && ! -e "$data" ]]; then
            mkdir "$data"
        fi
        echo "already linked: $name"
        return
    fi
    if [[ -e "$game" ]]; then
        mv "$game" "$data"
        echo "moved:          $name"
    elif [[ "$kind" == dir && ! -e "$data" ]]; then
        mkdir "$data"
    fi
    ln -s "$data" "$game"
    echo "linked:         $name"
}

for name in "${DIRS[@]}"; do move_and_link "$name" dir; done
for name in "${FILES[@]}"; do move_and_link "$name" file; done

echo
echo "Persistent data lives in:"
echo "  $DATA"

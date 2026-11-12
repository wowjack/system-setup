#!/usr/bin/env bash
set -euo pipefail

FACTORIO="$HOME/factorio"
DATA="$HOME/.factorio"

mkdir -p "$DATA"

move_and_link() {
    local name="$1"

    rm -rf "${FACTORIO:?}/${name:?}"
    ln -s "$DATA/$name" "$FACTORIO/$name"
}

move_and_link config
move_and_link mods
move_and_link saves
move_and_link blueprint-storage-2.dat
move_and_link player-data.json
move_and_link achievements-modded.dat

echo
echo "Done."
echo
echo "Persistent data lives in:"
echo "  $DATA"

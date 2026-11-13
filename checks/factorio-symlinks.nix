# utils/factorio-setup-symlinks.sh in a throwaway home directory: it moves the
# game's data into ~/.factorio and links it back, can be run again (also after
# reinstalling the game), and stops without changing anything on a conflict.
{ pkgs }:
pkgs.runCommand "check-factorio-symlinks" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  export HOME="$TMPDIR/home"
  run() { bash ${../utils/factorio-setup-symlinks.sh}; }
  fail() { echo "FAIL: $*" >&2; ls -laR "$HOME" >&2; exit 1; }
  linked() { [ "$(readlink "$HOME/factorio/$1")" = "$HOME/.factorio/$1" ] || fail "$1 is not linked"; }
  dirs="config mods saves"
  files="blueprint-storage-2.dat player-data.json achievements-modded.dat"

  # No game installed: error, nothing created.
  mkdir -p "$HOME"
  if run; then fail "accepted a missing ~/factorio"; fi
  [ ! -e "$HOME/.factorio" ] || fail "created ~/.factorio without a game"

  # First run on a played install: data is moved, then linked.
  mkdir -p "$HOME/factorio/bin" "$HOME/factorio/config" "$HOME/factorio/saves"
  echo cfg > "$HOME/factorio/config/config.ini"
  echo save > "$HOME/factorio/saves/a.zip"
  echo '{}' > "$HOME/factorio/player-data.json"
  run
  for name in $dirs $files; do linked "$name"; done
  [ "$(cat "$HOME/.factorio/config/config.ini")" = cfg ] || fail "config not moved"
  [ "$(cat "$HOME/.factorio/saves/a.zip")" = save ] || fail "saves not moved"
  [ "$(cat "$HOME/.factorio/player-data.json")" = '{}' ] || fail "player-data.json not moved"
  [ -d "$HOME/.factorio/mods" ] || fail "missing mods directory not created"
  [ ! -e "$HOME/.factorio/blueprint-storage-2.dat" ] || fail "created a file the game hadn't"

  # Running again changes nothing.
  cp -a "$HOME" "$TMPDIR/before"
  run
  diff -r --no-dereference "$TMPDIR/before" "$HOME" || fail "second run changed something"

  # Reinstalling the game: the kept data is linked into the fresh install.
  rm -rf "$HOME/factorio"
  mkdir -p "$HOME/factorio/bin"
  run
  for name in $dirs $files; do linked "$name"; done
  [ "$(cat "$HOME/factorio/saves/a.zip")" = save ] || fail "saves not reachable after reinstall"

  # Data in both places: stop before changing anything, keep both copies.
  rm -rf "$HOME/factorio"
  mkdir -p "$HOME/factorio/saves"
  echo other > "$HOME/factorio/saves/b.zip"
  cp -a "$HOME" "$TMPDIR/conflict"
  if run 2> err; then fail "accepted data in both places"; fi
  grep -q "saves exists in both" err || fail "conflict not reported: $(cat err)"
  diff -r --no-dereference "$TMPDIR/conflict" "$HOME" || fail "changed files despite a conflict"

  # A symlink to somewhere else: stop before changing anything.
  rm -rf "$HOME/factorio/saves"
  ln -s /elsewhere "$HOME/factorio/saves"
  if run 2> err; then fail "accepted a foreign symlink"; fi
  grep -q "not to $HOME/.factorio/saves" err || fail "foreign symlink not reported: $(cat err)"
  [ ! -e "$HOME/factorio/config" ] || fail "changed files despite a foreign symlink"

  touch $out
''

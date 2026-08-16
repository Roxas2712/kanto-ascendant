#!/bin/zsh
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MOD_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Read-only or apply, both require a stable snapshot. Never stop the app for
# the player and never guess that a running process is harmless.
RUNNING=$(ps -axo pid=,command= | awk '
  /[g]en1recomp/ { print; next }
  /[l]ove.*pokemon-love2d/ { print; next }
  /[Pp]okemon.*[Ll][Oo][Vv][Ee]/ { print; next }
')
if [[ -n "$RUNNING" ]]; then
  echo "ABBRUCH: Pokémon/gen1recomp/LÖVE läuft noch."
  echo "Spiel vollständig schließen und diesen Migrator danach erneut starten."
  echo "$RUNNING"
  exit 3
fi

LUA_BIN=${KA_LUAJIT:-}
for candidate in \
  "$LUA_BIN" \
  "$MOD_ROOT/../../gen1recomp/.tools/luajit-src/src/luajit" \
  "$MOD_ROOT/../gen1recomp/.tools/luajit-src/src/luajit" \
  "$(command -v luajit 2>/dev/null || true)"
do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    LUA_BIN=$candidate
    break
  fi
done
if [[ -z "$LUA_BIN" || ! -x "$LUA_BIN" ]]; then
  echo "ABBRUCH: LuaJIT nicht gefunden."
  echo "KA_LUAJIT auf die mit gen1recomp gebaute LuaJIT-Datei setzen."
  exit 4
fi

ENGINE_DIR=${GEN1RECOMP_DIR:-}
for candidate in \
  "$ENGINE_DIR" \
  "$MOD_ROOT/../../gen1recomp" \
  "$MOD_ROOT/../gen1recomp" \
  "$MOD_ROOT/../engine-0.1.86-exact"
do
  if [[ -n "$candidate" && -f "$candidate/src/core/SaveSerializer.lua" ]]; then
    ENGINE_DIR=$candidate
    break
  fi
done
if [[ -z "$ENGINE_DIR" || ! -f "$ENGINE_DIR/src/core/SaveSerializer.lua" ]]; then
  echo "ABBRUCH: entpackte gen1recomp-0.1.86-Engine nicht gefunden."
  echo "GEN1RECOMP_DIR auf das Engine-Verzeichnis setzen."
  exit 5
fi

HAS_ROOT=false
for value in "$@"; do
  if [[ "$value" == "--root" ]]; then HAS_ROOT=true; break; fi
done

ARGS=("$@")
if [[ "$HAS_ROOT" == false ]]; then
  ARGS+=(--root "$HOME/Library/Application Support/pokemon-love2d")
fi
ARGS+=(--engine "$ENGINE_DIR" --mod-root "$MOD_ROOT" --app-stopped-confirmed)

echo "Kanto Ascendant Legacy 0.1.86 — Offline-Migration"
echo "Ohne --apply bleibt dies eine reine Vorschau."
exec "$LUA_BIN" "$SCRIPT_DIR/migrate_legacy_archive_0186.lua" "${ARGS[@]}"

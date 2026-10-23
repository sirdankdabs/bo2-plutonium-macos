#!/bin/bash
# EXPERIMENTAL, UNTESTED: start the BO2 campaign executable from the game folder
# with the same patched runner and DXMT, without Plutonium (which has no BO2
# campaign). Based on run.sh from LuidgiAlt/plutonium-mac.
#   ./run-sp.sh
#   BO2_DIR=...        game folder (default: the path saved by install.sh)
#   SP_EXE=...         campaign executable in that folder (default: t6sp.exe)
# Options:
#   PLUTONIUM_DIR=...  Plutonium folder (default: %LOCALAPPDATA%\Plutonium in the prefix)
#   RENDERER=dxmt      DXMT instead of wined3d for Direct3D 10/11 (BO2); tested with
#                      v0.80 (setup.sh DXMT_ARCHIVE=...), recommended for BO2
#   MAXFPS=<n>         with DXMT: cap the frame rate with Metal's frame pacing
#   LAZY_EXEC=0        turn the stall fix off
#   SOCKFIX=0          turn patch 0006 off (every socket receive asks wineserver)
#   WINDOWED=1         force Windowed mode in BO2
#   D3D9=vulkan        wined3d's Vulkan renderer for Direct3D 9 games (BO1, WaW)
#                      instead of OpenGL; uses the persistent pipeline cache
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
runner="$here/runner/CrossOver"
[ -d "$runner" ] && [ -d "$here/prefix" ] || { echo "run ./setup.sh first" >&2; exit 1; }

export CX_ROOT="$runner" WINEPREFIX="$here/prefix" WINESERVER="$runner/bin/wineserver"
export CX_HOME="$HOME/Library/Application Support/CrossOver"
export WINEDLLPATH="$runner/lib/wine/x86_64-windows:$runner/lib/wine/x86_64-unix"
export WINEMSYNC=1 WINEDEBUG=-all
wine="$runner/lib/wine/x86_64-unix/wine"
lib="$runner/lib"
appdata_plutonium="$WINEPREFIX/drive_c/users/crossover/AppData/Local/Plutonium"
plutonium=${PLUTONIUM_DIR:-$appdata_plutonium}
renderer=${RENDERER:-wined3d}
case "$renderer" in wined3d|dxmt) ;; *) echo "RENDERER must be wined3d or dxmt" >&2; exit 1 ;; esac

case "${1:-}" in
t6zm|t6mp) ;;
kill) "$WINESERVER" -k; exit 0 ;;
install) exec "$wine" "${2:?path to plutonium.exe}" ;;
esac

# Check for the campaign before stopping anything that runs in the prefix.
game_dir=${BO2_DIR:-$(cat "$here/../game-dir.txt" 2>/dev/null || true)}
sp_exe=${SP_EXE:-t6sp.exe}
[ -f "$game_dir/$sp_exe" ] || { echo "no $sp_exe in '$game_dir': the campaign files are needed" >&2; exit 1; }

# Plutonium sets x86 hardware breakpoints, which Rosetta cannot deliver; the
# patched ntdll emulates them. Lazy exec removes the stalls caused by the
# bootstrapper turning off DEP (it has no NX_COMPAT flag).
vars=(WINE_ROSETTA_EXEC_BREAKPOINTS=1 WINE_ROSETTA_WOW64_BREAKPOINTS=1 WINE_ROSETTA_CALL_WORKAROUND=1
      "WINE_ROSETTA_LAZY_EXEC=${LAZY_EXEC:-1}" "WINE_SOCK_FASTPATH=${SOCKFIX:-1}"
      "CX_GRAPHICS_BACKEND=$renderer")
"$WINESERVER" -k 2>/dev/null || true
"$WINESERVER" -w 2>/dev/null || true

# Install a file only if it differs, by rename so nothing maps a half-written file.
put() { cmp -s "$1" "$2" || { cp "$1" "$2.swap" && mv -f "$2.swap" "$2"; }; }
# RENDERER=dxmt: DXMT's d3d11, dxgi, d3d10core and winemetal replace Wine's
# builtins, as tested with BO2; otherwise CrossOver's originals are put back.
for arch in i386-windows x86_64-windows; do
  for dll in d3d11 dxgi d3d10core winemetal; do
    if [ "$renderer" = dxmt ]; then put "$lib/dxmt/$arch/$dll.dll" "$lib/wine/$arch/$dll.dll"
    elif [ -f "$lib/wine/$arch/$dll.dll.orig" ]; then put "$lib/wine/$arch/$dll.dll.orig" "$lib/wine/$arch/$dll.dll"; fi
  done
done
if [ "$renderer" = dxmt ]; then put "$lib/dxmt/x86_64-unix/winemetal.so" "$lib/wine/x86_64-unix/winemetal.so"
else rm -f "$lib/wine/x86_64-unix/winemetal.so"; fi
# The launcher starts each game with a fresh Windows environment built from
# HKCU\Environment, so the variables are set there as well as here.
for v in "${vars[@]}"; do
  export "$v"
  "$wine" reg add 'HKCU\Environment' /v "${v%%=*}" /d "${v#*=}" /f > /dev/null 2>&1
done
# With DXMT, wined3d only backs the bootstrapper's DirectDraw use: no 3D.
bootstrapper='HKCU\Software\Wine\AppDefaults\plutonium-bootstrapper-win32.exe\Direct3D'
if [ "$renderer" = dxmt ]; then
  "$wine" reg add "$bootstrapper" /v renderer /d no3d /f > /dev/null 2>&1
else
  "$wine" reg delete "$bootstrapper" /v renderer /f > /dev/null 2>&1 || true
fi
# MAXFPS=<n>: DXMT paces frames through Metal and Core Animation at that rate.
# ASYNC=1 (default): draws whose pipeline is still compiling are skipped instead of
# stalling the frame (patched d3d11.dll); ASYNC=0 waits as stock DXMT does.
dxmt_config=""
if [ -n "${MAXFPS:-}" ]; then dxmt_config+="d3d11.preferredMaxFrameRate=$MAXFPS;"; fi
if [ "${ASYNC:-1}" = 1 ]; then dxmt_config+="d3d11.asyncPipelineCompile=True;"; fi
if [ -n "$dxmt_config" ]; then
  "$wine" reg add 'HKCU\Environment' /v DXMT_CONFIG /d "$dxmt_config" /f > /dev/null 2>&1
else
  "$wine" reg delete 'HKCU\Environment' /v DXMT_CONFIG /f > /dev/null 2>&1 || true
fi
# wined3d renders Direct3D 9 with OpenGL unless told otherwise.
if [ "${D3D9:-}" = vulkan ]; then
  "$wine" reg add 'HKCU\Software\Wine\Direct3D' /v renderer /d vulkan /f > /dev/null 2>&1
else
  "$wine" reg delete 'HKCU\Software\Wine\Direct3D' /v renderer /f > /dev/null 2>&1 || true
fi
"$WINESERVER" -w 2>/dev/null || true

# Plutonium keeps its settings and logs in %LOCALAPPDATA%\Plutonium even when
# it runs from another folder, so the config fixes above would miss them. With
# PLUTONIUM_DIR set, that folder becomes a link to it.
if [ "$plutonium" != "$appdata_plutonium" ] && [ ! -L "$appdata_plutonium" ]; then
  if [ -e "$appdata_plutonium" ]; then
    echo "PLUTONIUM_DIR is set, but the prefix also has $appdata_plutonium." >&2
    echo "Move or delete that folder so Plutonium uses $plutonium, then start again." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$appdata_plutonium")" && ln -s "$plutonium" "$appdata_plutonium"
fi

# Apple GPUs support at most 4x MSAA; BO2 crashes when its config asks for 8x.
for cfg in "$plutonium"/storage/t6/players/plutonium_{zm,mp}.cfg; do
  [ -f "$cfg" ] || continue
  sed -i '' -E 's/^seta r_aaSamples "(8|16|32)"/seta r_aaSamples "4"/' "$cfg"
  if [ "${WINDOWED:-0}" = 1 ]; then sed -i '' 's/^seta r_fullscreen "[0-9]*"/seta r_fullscreen "0"/' "$cfg"; fi
done

# Campaign: run the executable as it is in the game folder.
mkdir -p "$here/../logs"
cd "$game_dir"
exec "$wine" "$sp_exe" > "$here/../logs/campaign.log" 2>&1

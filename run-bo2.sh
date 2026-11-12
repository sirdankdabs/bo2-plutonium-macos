#!/bin/bash
# Run Black Ops II (Plutonium t6) on plutonium-mac-aio's engine (build/aio,
# from scripts/setup-aio.sh): CrossOver 26.3's Wine with the Rosetta
# breakpoint patches plus x87sidecar (BO2's x87 physics and effects maths run
# fast under Rosetta), and this project's DXMT (Direct3D 11 -> Metal) with
# background pipeline compilation. The prefix is the one install.sh builds.
#   ./run-bo2.sh                 Plutonium launcher (online)
#   ./run-bo2.sh t6zm [name]     Zombies, offline LAN
#   ./run-bo2.sh t6mp [name]     Multiplayer, offline LAN
#   ./run-bo2.sh kill            stop everything in the prefix
# Options (also as NAME=value lines in settings.conf; the environment wins):
#   BO2_DIR=...    Black Ops II folder (default: the folder that contains this one)
#   MAXFPS=<n>     cap the frame rate with DXMT's Metal frame pacing (0: no cap);
#                  a whole fraction of the refresh rate paces best
#   X87=0          turn the x87 acceleration off
#   X87_SIDECAR=athei|aio  which x87 accelerator: athei's x87sidecar or the aio engine's build
#   ASYNC=0        stock DXMT: wait for pipelines instead of skipping the draw
#   WINDOWED=1 / FULLSCREEN=1   display mode
#   CAPTURE=0      fullscreen without Wine capturing the display
#   NATIVE_MODE=0  in fullscreen, keep the desktop's (possibly HiDPI-scaled) mode
#   RAW_INPUT=0    keep the game's raw_input (default: on)
#   RUMBLE_FIX=0   Wine's original xinput (vibration then delays controller input)
#   AIM_ACCEL=1    keep the game's stick turn-rate acceleration (default: off)
#   STICK_DEADZONE=<n>   stick deadzone (default 0.08; the game's is 0.2)
#   GAMEMODE=0     don't declare Wine a game (macOS Game Mode)
#   HUD=1          Apple's Metal performance HUD (FPS and frame times)
#   SHOWFPS=1      the game's own FPS counter
#   BO2_ARGS="..." extra game arguments (LAN modes)
#   LAZY_EXEC=0, SOCKFIX=0   turn off performance patches
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$here/settings.conf" ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue ;; esac
    k=${k//[[:space:]]/}; v=${v%%#*}; v=${v%"${v##*[![:space:]]}"}
    [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] && [ -z "${!k+x}" ] && export "$k=$v"
  done < "$here/settings.conf"
fi
bo2=${BO2_DIR:-$(dirname "$here")}
prefix="$here/build/plutonium-mac/prefix"
engine="$here/build/aio/engine"
[ -d "$prefix/drive_c" ] || { echo "prefix not found at $prefix: run ./install.sh" >&2; exit 1; }
[ -f "$engine/lib/wine/x86_64-unix/ntdll.so.fixed" ] || { echo "engine missing at $engine: run scripts/setup-aio.sh" >&2; exit 1; }

export WINEPREFIX="$prefix" WINESERVER="$engine/bin/wineserver"
export WINEDLLPATH="$engine/lib/wine/x86_64-windows:$engine/lib/wine/x86_64-unix"
export PATH="$engine/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export WINEMSYNC=1 WINEDEBUG=-all
wine="$engine/lib/wine/x86_64-unix/wine"
plutonium="$WINEPREFIX/drive_c/users/crossover/AppData/Local/Plutonium"
mode=${1:-launcher}

# Stop whatever runs in the prefix: this engine, the CrossOver runner
# install.sh built, or bo1-plutonium-macos's engine.
stop_all() {
  local s
  for s in "$WINESERVER" "$here/build/plutonium-mac/runner/CrossOver/bin/wineserver" \
           "$here/../../bo1/bo1-plutonium-macos/runner/engine/bin/wineserver"; do
    [ -x "$s" ] && WINESERVER="$s" "$s" -k 2>/dev/null || true
  done
  "$WINESERVER" -w 2>/dev/null || true
}
case "$mode" in
kill) stop_all; exit 0 ;;
launcher|t6zm|t6mp) ;;
*) echo "usage: $0 [launcher|t6zm|t6mp|kill] [player name]" >&2; exit 1 ;;
esac
[ -d "$bo2/zone" ] || { echo "Black Ops II folder not found: $bo2 (set BO2_DIR)" >&2; exit 1; }
stop_all

reg() { "$wine" reg "$@" > /dev/null 2>&1 || true; }
set_env() { export "$1=$2"; reg add 'HKCU\Environment' /v "$1" /d "$2" /f; }
clear_env() { unset "$1"; reg delete 'HKCU\Environment' /v "$1" /f; }
put() { cmp -s "$1" "$2" || { cp "$1" "$2.swap" && mv -f "$2.swap" "$2"; }; }

put "$engine/lib/wine/x86_64-unix/ntdll.so.fixed" "$engine/lib/wine/x86_64-unix/ntdll.so"
# Vibration without input delay (patches/xinput): Wine's XInputSetState wrote
# each vibration change to the controller synchronously, holding the lock the
# input-reading thread needs, so input reached the game late on every shot.
# The patched xinput1_3.dll sends vibration from its own thread. RUMBLE_FIX=0
# puts Wine's original back.
xi="$engine/lib/wine/i386-windows/xinput1_3.dll"
[ -f "$xi.orig" ] || cp -p "$xi" "$xi.orig"
if [ "${RUMBLE_FIX:-1}" = 1 ]; then put "$here/patches/xinput/xinput1_3.dll" "$xi"; else put "$xi.orig" "$xi"; fi
# Game Mode: macOS gives a fullscreen game CPU/GPU priority, but only to apps
# declared as games. Declare Wine's loader one (GAMEMODE=0 skips it).
if [ "${GAMEMODE:-1}" = 1 ] && ! grep -aq LSApplicationCategoryType "$wine" 2>/dev/null; then
  [ "$(/usr/bin/python3 -I "$here/tools/gamemode-plist.py" "$wine" 2>/dev/null)" = patched ] &&
    codesign -fs - "$wine" 2>/dev/null
fi
# Wine updates a prefix whenever wine.inf's date differs from the one it last
# saw. The engines ship the same wine.inf: give them the same date, so they can
# take turns on this prefix without a slow update.
cx_inf="$here/build/plutonium-mac/runner/CrossOver/share/wine/wine.inf"
if [ -f "$cx_inf" ] && cmp -s "$cx_inf" "$engine/share/wine/wine.inf"; then
  touch -r "$cx_inf" "$engine/share/wine/wine.inf"
fi
export WINEDLLOVERRIDES="mscoree,mshtml="
bootstrapper='HKCU\Software\Wine\AppDefaults\plutonium-bootstrapper-win32.exe'
# Direct3D 11 is DXMT's; wined3d only backs the bootstrapper's DirectDraw use.
reg add "$bootstrapper\\Direct3D" /v renderer /d no3d /f
reg add "$bootstrapper\\Direct3D" /v VideoMemorySize /d 4096 /f
# Fullscreen: Wine captures the display, so macOS shows frames directly instead
# of composing the game's window (in BO1 that took fullscreen from ~75 to
# 160+ FPS). CAPTURE=0 turns it off.
if [ "${CAPTURE:-1}" = 1 ]; then reg add "$bootstrapper\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
else reg delete "$bootstrapper\\Mac Driver" /v CaptureDisplaysForFullscreen /f; fi
reg delete 'HKCU\Software\Wine\Direct3D' /v renderer /f
reg add 'HKCU\Software\Wine\AppDefaults\plutonium-launcher-win32.exe\Direct3D' /v renderer /d gl /f
set_env WINE_ROSETTA_EXEC_BREAKPOINTS 1
set_env WINE_ROSETTA_WOW64_BREAKPOINTS 1
set_env WINE_ROSETTA_CALL_WORKAROUND 1
set_env WINE_ROSETTA_LAZY_EXEC "${LAZY_EXEC:-1}"
set_env WINE_SOCK_FASTPATH "${SOCKFIX:-1}"
if [ "${X87:-1}" = 1 ]; then set_env WINE_X87_SIDECAR plutonium-bootstrapper-win32.exe; else clear_env WINE_X87_SIDECAR; fi
# Which x87 accelerator Wine starts the game under (bin/x87sidecar):
# X87_SIDECAR=athei  athei's x87sidecar 1.9.1 (build/x87sidecar, its release),
#                    which grew from Lifeisawful's rosettax87;
# X87_SIDECAR=aio    the aio engine's reduced, hardened build of it.
side="$engine/bin/x87sidecar"
[ -f "$side.aio" ] || cp -p "$side" "$side.aio"
if [ "${X87_SIDECAR:-aio}" = athei ] && [ -x "$here/build/x87sidecar/x87sidecar" ]; then
  put "$here/build/x87sidecar/x87sidecar" "$side"
else
  put "$side.aio" "$side"
fi
if [ "${HUD:-0}" = 1 ]; then set_env MTL_HUD_ENABLED 1; else clear_env MTL_HUD_ENABLED; fi
clear_env CX_GRAPHICS_BACKEND
"$WINESERVER" -w 2>/dev/null || true

winpath="Z:${bo2//\//\\}"
# Point the Plutonium launcher at this Black Ops II folder.
cfg="$plutonium/config.json"
if [ -f "$cfg" ]; then
  BO2WIN="$winpath" /usr/bin/python3 -I - "$cfg" <<'PY'
import json, os, sys
p = sys.argv[1]
c = json.load(open(p))
if c.get("t6Path") != os.environ["BO2WIN"]:
    c["t6Path"] = os.environ["BO2WIN"]
    json.dump(c, open(p, "w"), separators=(",", ":"))
PY
fi

# BO2's configs. MSAA and fullscreen also live in its binary hardware profile;
# with none in Plutonium's storage, BO2 falls back to the game folder's, which
# another renderer may have written with 8x (Apple GPUs stop at 4x: crash). An
# all-zero profile makes BO2 detect a safe one (as plutonium-mac-aio does).
players="$plutonium/storage/t6/players"
mkdir -p "$players"
for m in mp zm; do [ -f "$players/hardware_$m.chp" ] || head -c 4096 /dev/zero > "$players/hardware_$m.chp"; done
set_cvar() { sed -i '' -E "s/^seta $2 \"[^\"]*\"/seta $2 \"$3\"/" "$1"; }
set_or_add() { if grep -q "^seta $2 " "$1"; then set_cvar "$@"; else printf 'seta %s "%s"\n' "$2" "$3" >> "$1"; fi; }
read -r dw dh hz < <("$here/tools/displaymode" current 2>/dev/null || true)
desktop=${dw:+${dw}x$dh}
for cfg in "$players"/plutonium_zm.cfg "$players"/plutonium_mp.cfg; do
  [ -f "$cfg" ] || continue
  sed -i '' -E 's/^seta r_aaSamples "(8|16|32)"/seta r_aaSamples "4"/' "$cfg"
  # A mode larger than the desktop may not exist (e.g. a monitor switched to
  # 1080p at 320 Hz), and 800x600 is blurry: the game gets the desktop's size.
  if [ -n "$desktop" ]; then
    rmode=$(sed -n -E 's/^seta r_mode "([0-9]+)x[0-9]+"/\1/p' "$cfg")
    if [ "$rmode" = 800 ] || { [ -n "$rmode" ] && [ "$rmode" -gt "${desktop%x*}" ]; }; then
      set_cvar "$cfg" r_mode "$desktop"
    fi
  fi
  if [ "${RAW_INPUT:-1}" = 1 ]; then set_cvar "$cfg" raw_input 1; set_cvar "$cfg" m_filter 0; fi
  # Aiming feel: no turn-rate ramp-up on the sticks (it felt like input delay;
  # AIM_ACCEL=1 keeps the game's), a smaller stick deadzone (STICK_DEADZONE,
  # default 0.08 instead of 0.2) and no in-game mouse acceleration.
  if [ "${AIM_ACCEL:-0}" = 0 ]; then set_or_add "$cfg" aim_accel_turnrate_enabled 0; fi
  set_or_add "$cfg" gpad_stick_deadzone_min "${STICK_DEADZONE:-0.08}"
  set_or_add "$cfg" cl_mouseAccel 0
  # The frame rate is capped by DXMT (MAXFPS), not by the game's com_maxfps.
  set_cvar "$cfg" com_maxfps 0
  if [ "${WINDOWED:-0}" = 1 ]; then set_cvar "$cfg" r_fullscreen 0; fi
  if [ "${FULLSCREEN:-0}" = 1 ]; then set_cvar "$cfg" r_fullscreen 1; fi
done

# DXMT: draws whose pipeline is still compiling are skipped for a moment
# instead of freezing the frame (ASYNC=0: stock behaviour); frame pacing
# through Metal at MAXFPS (default: the display's refresh rate; 0: none).
dxmt_config=""
maxfps=${MAXFPS:-${hz:-0}}
if [ "$maxfps" != 0 ]; then dxmt_config+="d3d11.preferredMaxFrameRate=$maxfps;"; fi
if [ "${ASYNC:-1}" = 1 ]; then dxmt_config+="d3d11.asyncPipelineCompile=True;"; fi
if [ -n "$dxmt_config" ]; then set_env DXMT_CONFIG "$dxmt_config"; else clear_env DXMT_CONFIG; fi

mkdir -p "$here/logs"
# Fullscreen: while the game runs, a 1x display mode of the game's resolution
# (tools/displaymode; macOS restores the desktop's mode when it exits), so a
# HiDPI-scaled desktop does not make macOS compose every frame at 2x.
case "$mode" in t6mp) gamecfg=plutonium_mp.cfg ;; *) gamecfg=plutonium_zm.cfg ;; esac
gamecfg="$players/$gamecfg"
if [ "${NATIVE_MODE:-1}" = 1 ] && [ -x "$here/tools/displaymode" ] && [ -f "$gamecfg" ] &&
   grep -q '^seta r_fullscreen "1"' "$gamecfg"; then
  res=$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)"/\1 \2/p' "$gamecfg")
  if [ -n "$res" ]; then
    # shellcheck disable=SC2086
    "$here/tools/displaymode" $res $$ >> "$here/logs/displaymode.log" 2>&1 &
  fi
fi
if [ "$mode" = launcher ]; then
  launcher="$plutonium/bin/plutonium-launcher-win32.exe"
  [ -f "$launcher" ] || { echo "no Plutonium launcher at $launcher" >&2; exit 1; }
  cd "$plutonium/bin"
  exec "$wine" "$launcher" > "$here/logs/launcher.log" 2>&1
fi
name=${2:-Player}
cd "$plutonium"
exec "$wine" bin/plutonium-bootstrapper-win32.exe "$mode" "$winpath" +name "$name" -lan ${SHOWFPS:+ +set cg_drawFPS 1} ${BO2_ARGS:-} > "$here/logs/lan-$mode.log" 2>&1

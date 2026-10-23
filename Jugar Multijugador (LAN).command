#!/bin/bash
# BO2 Multiplayer offline (LAN), no account needed. Player name: name.txt next to this file.
here=$(cd -- "$(dirname -- "$0")" && pwd)
name=$(head -n1 "$here/name.txt" 2>/dev/null || echo Player)
RENDERER=dxmt WINDOWED=1 exec "$here/build/plutonium-mac/run-lan.sh" t6mp "${name:-Player}"

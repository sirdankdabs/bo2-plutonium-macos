#!/bin/bash
# BO2 Multiplayer offline (LAN), no account needed. Player name: name.txt next to this file.
here=$(cd -- "$(dirname -- "$0")" && pwd)
name=$(head -n1 "$here/name.txt" 2>/dev/null || echo Player)
exec "$here/run-bo2.sh" t6mp "${name:-Player}"

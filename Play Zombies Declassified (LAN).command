#!/bin/bash
# Zombies Declassified (BO1's zombies maps in BO2) offline (LAN): starts BO2
# Zombies with the mod loaded; pick the map in its menu. Install the mod first
# with scripts/zombies-declassified.sh. Online: in the game, Mods -> dlc5.
here=$(cd -- "$(dirname -- "$0")" && pwd)
name=$(head -n1 "$here/name.txt" 2>/dev/null || echo Player)
BO2_ARGS="+set fs_game mods/dlc5 ${BO2_ARGS:-}" exec "$here/run-bo2.sh" t6zm "${name:-Player}"

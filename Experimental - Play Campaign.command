#!/bin/bash
# EXPERIMENTAL, UNTESTED: BO2 campaign (t6sp.exe in the game folder), no Plutonium.
here=$(cd -- "$(dirname -- "$0")" && pwd)
cp "$here/scripts/run-sp.sh" "$here/build/plutonium-mac/run-sp.sh" 2>/dev/null
RENDERER=dxmt WINDOWED=1 exec "$here/build/plutonium-mac/run-sp.sh"

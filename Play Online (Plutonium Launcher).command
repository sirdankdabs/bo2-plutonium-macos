#!/bin/bash
# Plutonium launcher: sign in and play online.
here=$(cd -- "$(dirname -- "$0")" && pwd)
RENDERER=dxmt WINDOWED=1 exec "$here/build/plutonium-mac/run.sh"

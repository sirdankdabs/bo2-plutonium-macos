#!/bin/bash
# Plutonium launcher: sign in and play online (settings: settings.conf).
here=$(cd -- "$(dirname -- "$0")" && pwd)
exec "$here/run-bo2.sh" launcher

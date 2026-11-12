#!/bin/bash
# Zombies Declassified (github.com/Logo-2K/zombies-declassified): Black Ops II's
# unreleased "DLC 5", BO1's zombies maps ported to BO2, as a Plutonium mod.
# Installs it with the project's own cross-platform installer (zdinstall.py,
# from the release), which downloads each file (~9 GB), checks its SHA-256 and
# backs up anything it replaces under ~/.zombies-declassified/backups.
#   scripts/zombies-declassified.sh            install or update to the latest release
#   scripts/zombies-declassified.sh verify     check the installed files
#   scripts/zombies-declassified.sh dry-run    show the plan, change nothing
#   ZD_TAG=<tag>   a given release instead of the latest
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
bo2=${BO2_DIR:-$(dirname "$here")}
t6="$here/build/plutonium-mac/prefix/drive_c/users/crossover/AppData/Local/Plutonium/storage/t6"
repo=Logo-2K/zombies-declassified
[ -d "$bo2/zone" ] && [ -d "$bo2/sound" ] || { echo "no Black Ops II in $bo2 (set BO2_DIR)" >&2; exit 1; }
[ -d "$t6" ] || { echo "no Plutonium storage at $t6: run ./install.sh and start BO2 once" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if [ -n "${ZD_TAG:-}" ]; then api="https://api.github.com/repos/$repo/releases/tags/$ZD_TAG"
else api="https://api.github.com/repos/$repo/releases/latest"; fi
curl -fsSL "$api" -o "$work/release.json"
url() { /usr/bin/python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1]))
print(next(a["browser_download_url"] for a in r["assets"] if a["name"]==sys.argv[2]))' "$work/release.json" "$1"; }
tag=$(/usr/bin/python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["tag_name"])' "$work/release.json")
echo "Zombies Declassified release: $tag"
curl -fsSL "$(url zdinstall.py)" -o "$work/zdinstall.py"
curl -fsSL "$(url manifest.json)" -o "$work/manifest.json"

case "${1:-install}" in
install) extra=() ;;
verify) extra=(--verify) ;;
dry-run) extra=(--dry-run) ;;
*) echo "usage: $0 [install|verify|dry-run]" >&2; exit 2 ;;
esac
# The installer is run from its own folder, with Python's isolated mode.
/usr/bin/python3 -I -u "$work/zdinstall.py" --pluto "$t6" --bo2 "$bo2" --manifest "$work/manifest.json" ${extra[@]+"${extra[@]}"}

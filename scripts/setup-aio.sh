#!/bin/bash
# Install plutonium-mac-aio's engine (github.com/LuidgiAlt/plutonium-mac-aio,
# release v0.2.1) into build/aio, inside Sikarugir's wrapper template whose
# libraries it links against. It is CrossOver 26.3's Wine with the same Rosetta
# breakpoint patches, plus x87sidecar: BO2 does its physics and effects in x87
# maths, which Rosetta translates slowly (aio measured BO2 Zombies' lowest
# second at 37 FPS without it, 100 with it on an M1 Pro).
# Both downloads are checked against the SHA-256 in plutonium-mac-aio's
# manifest. DXMT (Direct3D 11 -> Metal) is the async-pipeline build that
# install.sh makes. Run again to repair.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
dl="$here/build/downloads/aio" r="$here/build/aio"
engine_url=https://github.com/LuidgiAlt/plutonium-mac-aio/releases/download/v0.2.1/plutonium-mac-aio-engine-0.2.1.tar.xz
engine_sha=c9e1861556acfcc1af3b81e6bc2ce62a184d2e3ec77b678a53a9586c796bf3c1
template_url=https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.24.tar.xz
template_sha=4b5f89eeb9ef139936bdfad33d9b420b05ea4597cb7d63376674f7a8e171321c
# bo1-plutonium-macos keeps the same two files; reuse them if they are there.
bo1_dl="$here/../../bo1/bo1-plutonium-macos/downloads"

fetch() { # file url sha256 [other copy]
  if [ ! -f "$1" ] && [ -n "${4:-}" ] && [ -f "$4" ]; then cp "$4" "$1"; fi
  if [ ! -f "$1" ] || [ "$(shasum -a 256 "$1" | cut -d' ' -f1)" != "$3" ]; then
    curl -fL# --retry 3 -o "$1.part" "$2" && mv "$1.part" "$1"
  fi
  [ "$(shasum -a 256 "$1" | cut -d' ' -f1)" = "$3" ] || { echo "$1: SHA-256 does not match" >&2; exit 1; }
}
mkdir -p "$dl" "$r"
fetch "$dl/engine.tar.xz" "$engine_url" "$engine_sha" "$bo1_dl/engine.tar.xz"
fetch "$dl/template.tar.xz" "$template_url" "$template_sha" "$bo1_dl/template.tar.xz"

rm -rf "$r/Sikarugir.app" "$r/engine"
tmp=$(mktemp -d "$r/.template.XXXXXX")
tar -xJf "$dl/template.tar.xz" -C "$tmp"
mv "$tmp"/*.app "$r/Sikarugir.app"
rmdir "$tmp"
tar -xJf "$dl/engine.tar.xz" -C "$r/Sikarugir.app/Contents/Frameworks/"
ln -s Sikarugir.app/Contents/Frameworks/wswine.bundle "$r/engine"

dxmt="$here/build/plutonium-mac/runner/CrossOver/lib/dxmt"
[ -f "$dxmt/i386-windows/d3d11.dll" ] || { echo "no DXMT build at $dxmt: run ./install.sh first" >&2; exit 1; }
for a in i386-windows x86_64-windows; do
  for d in d3d11 dxgi d3d10core winemetal; do
    dst="$r/engine/lib/wine/$a/$d.dll"
    [ ! -f "$dst" ] || [ -f "$dst.orig" ] || cp -p "$dst" "$dst.orig"
    cp "$dxmt/$a/$d.dll" "$dst"
  done
done
cp "$dxmt/x86_64-unix/winemetal.so" "$r/engine/lib/wine/x86_64-unix/winemetal.so"
codesign -fs - "$r/engine/lib/wine/x86_64-unix/winemetal.so"
# athei's x87sidecar (github.com/athei/x87sidecar), from its own release: the
# upstream of the accelerator inside the aio engine (which is a reduced build
# of it). Same cooperative handshake, so it drops into this Wine as is;
# run-bo2.sh picks one with X87_SIDECAR=athei|aio.
x87_url=https://github.com/athei/x87sidecar/releases/download/v1.9.1/x87sidecar.tar.xz
x87_sha=e18d1c2443f1440ae5a8e137dd0c85ec33e53506b67604675826094122106615
fetch "$dl/x87sidecar.tar.xz" "$x87_url" "$x87_sha"
rm -rf "$here/build/x87sidecar" && mkdir -p "$here/build/x87sidecar"
tar -xJf "$dl/x87sidecar.tar.xz" -C "$here/build/x87sidecar"
xattr -d com.apple.quarantine "$here/build/x87sidecar/x87sidecar" 2>/dev/null || true
cp -p "$r/engine/bin/x87sidecar" "$r/engine/bin/x87sidecar.aio"
"$here/build/x87sidecar/x87sidecar" --probe > /dev/null 2>&1 ||
  echo "note: athei's x87sidecar does not support this Rosetta; X87_SIDECAR=athei would run without acceleration" >&2
cat "$r/engine/version"
echo "aio engine installed in $r"

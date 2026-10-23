#!/bin/bash
# Set up Call of Duty: Black Ops II with Plutonium on an Apple Silicon Mac.
#   ./install.sh [game folder]
# The game folder must contain BO2's files (zone/, sound/, ...) and plutonium.exe.
# Without an argument, the folder that contains this repository is used.
# Everything is built and installed under ./build; nothing outside it is changed
# except Homebrew packages and DXMT's shader cache in macOS's cache folder.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
build="$here/build"

# Pinned versions: everything below was tested together.
crossover_build=26.3.0.39832
cx_src_url=https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz
cx_src_sha256=ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872
dxmt_url=https://github.com/3Shain/dxmt/releases/download/v0.80/dxmt-v0.80-builtin.tar.gz
dxmt_sha256=8f260e36b5739e68f3bad613381441385c4dc7b85b78ba8de653d5a6a264529d
dxmt_src_commit=589adb780354b461645b29999cefaf533594ee99   # v0.80
patches_repo=https://github.com/LuidgiAlt/crossover-rosetta-patches.git
patches_commit=43ebddfc161d4bfbb5e52e69e6b363af2136d2f0
plutomac_repo=https://github.com/LuidgiAlt/plutonium-mac.git
plutomac_commit=b5d44e3a34ebbaf134a2a9d17df6260327e0b8ce

step() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- Checks -------------------------------------------------------------------
game=${1:-}
if [ -z "$game" ]; then
  for d in "$(dirname "$here")" "$here"; do
    if [ -f "$d/plutonium.exe" ]; then game=$d; break; fi
  done
fi
[ -n "$game" ] || die "plutonium.exe not found. Put this folder inside the game folder or run: ./install.sh \"/path/to/Call of Duty Black Ops II\""
game=$(cd "$game" && pwd)
[ -f "$game/plutonium.exe" ] || die "no plutonium.exe in $game"
[ -d "$game/zone" ] || die "no zone/ folder in $game: is this the Black Ops II folder?"

[ "$(uname -m)" = arm64 ] || die "this is for Apple Silicon Macs"
/usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null || die "Rosetta 2 is missing: softwareupdate --install-rosetta --agree-to-license"
xcode-select -p > /dev/null 2>&1 || die "Xcode Command Line Tools are missing: xcode-select --install"
command -v brew > /dev/null || die "Homebrew is missing: https://brew.sh"
crossover=${CROSSOVER_APP:-/Applications/CrossOver.app}
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$crossover/Contents/Info.plist" 2>/dev/null || true)
[ "$version" = "$crossover_build" ] || die "CrossOver $crossover_build (26.3) is required at $crossover, found '${version:-none}'"
echo "Game folder: $game"

mkdir -p "$build/downloads" "$build/logs"
cd "$build"

# --- Tools --------------------------------------------------------------------
step "Installing build tools with Homebrew (mingw-w64, bison, flex, meson, ninja)"
brew install mingw-w64 bison flex meson ninja
brew_prefix=$(brew --prefix)
export PATH="$brew_prefix/opt/bison/bin:$brew_prefix/opt/flex/bin:$brew_prefix/bin:$PATH"

# --- Downloads ----------------------------------------------------------------
fetch() { # url sha256 file
  if [ ! -f "$3" ] || [ "$(shasum -a 256 "$3" | cut -d' ' -f1)" != "$2" ]; then
    curl -fL# --retry 3 -o "$3.part" "$1" && mv "$3.part" "$3"
  fi
  [ "$(shasum -a 256 "$3" | cut -d' ' -f1)" = "$2" ] || die "$3: SHA-256 does not match"
}
clone() { # repo commit dir
  [ -d "$3/.git" ] || git clone -q "$1" "$3"
  git -C "$3" fetch -q origin "$2" 2>/dev/null || git -C "$3" fetch -q origin
  git -C "$3" checkout -q --force "$2"
}
step "Downloading CrossOver 26.3 sources and DXMT v0.80"
fetch "$cx_src_url" "$cx_src_sha256" downloads/crossover-sources-26.3.0.tar.gz
fetch "$dxmt_url" "$dxmt_sha256" downloads/dxmt-v0.80-builtin.tar.gz
clone "$patches_repo" "$patches_commit" crossover-rosetta-patches
clone "$plutomac_repo" "$plutomac_commit" plutonium-mac

# --- Patched Wine (hardware breakpoints under Rosetta, stall fixes) ------------
wine_build="$build/crossover-rosetta-patches/build"
if [ ! -f "$wine_build/.done" ]; then
  step "Building patched Wine pieces (10-20 minutes)"
  cd "$build/crossover-rosetta-patches"
  rm -rf sources build
  tar -xzf "$build/downloads/crossover-sources-26.3.0.tar.gz" sources/wine
  (cd sources/wine && for p in ../../patches/000*.patch; do patch -p1 --forward < "$p" > /dev/null; done)
  mkdir build && cd build
  (
    export SDKROOT=$(xcrun --sdk macosx --show-sdk-path) MACOSX_DEPLOYMENT_TARGET=15.0 \
      CC='clang -arch x86_64' CXX='clang++ -arch x86_64' ac_cv_func_pipe2=no
    ../sources/wine/configure --host=x86_64-apple-darwin24 --enable-archs=i386,x86_64 \
      --disable-tests --without-x --without-wayland --without-gstreamer --without-ffmpeg \
      --without-freetype --without-gnutls --without-vulkan --without-oss --without-alsa \
      --without-pulse --without-sane --without-usb --without-v4l2 --without-pcap \
      --without-capi --without-opencl --without-cups
    make -j"$(sysctl -n hw.ncpu)" dlls/ntdll/ntdll.so server/wineserver \
      dlls/wined3d/i386-windows/wined3d.dll dlls/wined3d/x86_64-windows/wined3d.dll
  ) > "$build/logs/wine-build.log" 2>&1 || die "Wine build failed, see build/logs/wine-build.log"
  codesign -fs - dlls/ntdll/ntdll.so server/wineserver
  i686-w64-mingw32-strip --strip-debug dlls/wined3d/i386-windows/wined3d.dll
  x86_64-w64-mingw32-strip --strip-debug dlls/wined3d/x86_64-windows/wined3d.dll
  touch .done
  cd "$build"
fi

# --- Runner and prefix --------------------------------------------------------
step "Creating the Wine runner and prefix"
cp "$here/scripts/run.sh" "$here/scripts/run-lan.sh" "$build/plutonium-mac/"
DXMT_ARCHIVE="$build/downloads/dxmt-v0.80-builtin.tar.gz" "$build/plutonium-mac/setup.sh" "$wine_build"
echo "$game" > "$build/game-dir.txt"

# --- DXMT with asynchronous pipeline compilation (no shader stutter) ----------
dxmt_dll="$build/plutonium-mac/runner/CrossOver/lib/dxmt/i386-windows/d3d11.dll"
if [ ! -f "$build/dxmt-src/build32/src/d3d11/d3d11.dll" ]; then
  step "Building DXMT v0.80 with the async pipeline patch"
  clone https://github.com/3Shain/dxmt.git "$dxmt_src_commit" "$build/dxmt-src"
  cd "$build/dxmt-src"
  git submodule update -q --init --depth 1
  git apply "$here/patches/dxmt-async-pipeline-v0.80.patch"
  rm -rf build32
  {
    meson setup --cross-file build-win32.txt -Dwine_build_path="$wine_build" build32 --buildtype release
    meson compile -C build32
  } > "$build/logs/dxmt-build.log" 2>&1 || die "DXMT build failed, see build/logs/dxmt-build.log"
  cd "$build"
fi
cp -p "$dxmt_dll" "$dxmt_dll.v080"
cp "$build/dxmt-src/build32/src/d3d11/d3d11.dll" "$dxmt_dll"
i686-w64-mingw32-strip --strip-debug "$dxmt_dll"

# --- Plutonium ----------------------------------------------------------------
plutonium="$build/plutonium-mac/prefix/drive_c/users/crossover/AppData/Local/Plutonium"
if [ ! -f "$plutonium/bin/plutonium-launcher-win32.exe" ] && [ "${SKIP_PLUTONIUM:-0}" != 1 ]; then
  step "Installing Plutonium: its installer window opens; wait until the launcher appears, then close it"
  "$build/plutonium-mac/run.sh" install "$game/plutonium.exe" > "$build/logs/plutonium-install.log" 2>&1 || true
fi

step "Done"
echo "Game folder for the Plutonium launcher: Z:${game//\//\\}"
echo "Double-click a .command file in $here to play."

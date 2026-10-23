# Black Ops II + Plutonium on macOS (Apple Silicon)

Play **Call of Duty: Black Ops II** with **Plutonium** (Zombies and Multiplayer, online and LAN) on an Apple Silicon Mac, without a virtual machine.

Tested on a MacBook Pro with an M1 Pro: Zombies and Multiplayer launch, online play works after signing in, ~120 FPS, and no shader-compilation stutter.

## What it does

On macOS, Plutonium hangs at `Loading fastfile code_pre_gfx` because it uses x86 hardware breakpoints, which Rosetta 2 does not support. This project combines and automates:

1. **[crossover-rosetta-patches](https://github.com/LuidgiAlt/crossover-rosetta-patches)** (LuidgiAlt): Wine patches that emulate those breakpoints and remove stalls. They are built from CrossOver 26.3's public source code.
2. **[plutonium-mac](https://github.com/LuidgiAlt/plutonium-mac)** (LuidgiAlt): scripts that create a copy of CrossOver's runtime with the patches, plus a separate Wine prefix. CrossOver.app itself is not modified.
3. **[DXMT](https://github.com/3Shain/dxmt) v0.80** (Direct3D 11 → Metal), rebuilt with an extra patch (`patches/dxmt-async-pipeline-v0.80.patch`): while a shader is still compiling, that draw is skipped for a moment instead of freezing the frame (like DXVK-async). No more stutter when entering new areas.
4. An offline **LAN** launcher (no account needed) and fixes to the original scripts.

It does not include any game, Plutonium or CrossOver files.

## Requirements

- An **Apple Silicon** Mac (M1 or later) running macOS 15 or later.
- **Rosetta 2**: `softwareupdate --install-rosetta --agree-to-license`
- **Xcode Command Line Tools**: `xcode-select --install`
- **[Homebrew](https://brew.sh)**.
- **[CrossOver](https://www.codeweavers.com/crossover) 26.3** (build 26.3.0.39832) installed in `/Applications`. Its runtime is used, so you need a valid CrossOver license.
- Your copy of **Black Ops II** (the `zone/`, `sound/`, `video/` … folders) with **`plutonium.exe`** in the same folder. Get `plutonium.exe` from [plutonium.pw](https://plutonium.pw).
- About 10 GB of free space for the build.
- For online play: a [Plutonium](https://forum.plutonium.pw) account.

## Installation

1. Open Terminal and go to the game folder (the one with `plutonium.exe`):
   ```bash
   cd "/path/to/Call of Duty Black Ops II"
   ```
2. Download this project into that folder:
   ```bash
   git clone https://github.com/sirdankdabs/bo2-plutonium-macos.git
   ```
3. Run the installer (15–30 minutes the first time; it builds Wine and DXMT):
   ```bash
   cd bo2-plutonium-macos && ./install.sh
   ```
   If you put the project somewhere else, pass the game folder: `./install.sh "/path/to/Call of Duty Black Ops II"`.
4. At the end, the Plutonium installer opens: wait until it finishes downloading and the launcher appears. You can close it or sign in right away.

## Playing

Double-click the files in the `bo2-plutonium-macos` folder:

| File | What it does |
|---|---|
| `Play Online (Plutonium Launcher).command` | Opens the Plutonium launcher. Sign in, pick Black Ops II, click **Set up** and select the game folder (Wine shows it as `Z:\path\to\Call of Duty Black Ops II`; the installer prints the exact path), then click **Play**. |
| `Play Zombies (LAN).command` | Offline Zombies, no account needed. |
| `Play Multiplayer (LAN).command` | Offline Multiplayer, no account needed. |
| `Close BO2.command` | Stops everything running in Wine if something hangs. |

To set your LAN player name, create a `name.txt` file next to the `.command` files with your name on the first line.

If macOS blocks a `.command` file the first time: right-click it → **Open**.

## Troubleshooting

- **Crash with `sample count 8 is not supported`**: Apple GPUs support at most 4x MSAA. Lower anti-aliasing in the game (the scripts already clamp it in the config files).
- **A long pause while a map loads**: this is normal (it happens on Windows too).
- **Going back to stock DXMT** (without the async patch): run the launchers with `ASYNC=0`, or copy `build/plutonium-mac/runner/CrossOver/lib/dxmt/i386-windows/d3d11.dll.v080` over `d3d11.dll`.
- **Logs**: `build/logs/` and `build/plutonium-mac/prefix/drive_c/users/crossover/AppData/Local/Plutonium/console.log`.

## Options

Environment variables accepted by the launchers (`build/plutonium-mac/run.sh` and `run-lan.sh`):

- `ASYNC=0`: turns off background shader compilation.
- `MAXFPS=60`: caps the frame rate.
- `WINDOWED=1`: windowed mode (enabled in the `.command` files).
- `LAZY_EXEC=0`, `SOCKFIX=0`: turn off performance patches (for comparison).

## Credits and licenses

- [LuidgiAlt/crossover-rosetta-patches](https://github.com/LuidgiAlt/crossover-rosetta-patches) (LGPL-2.1+) and [LuidgiAlt/plutonium-mac](https://github.com/LuidgiAlt/plutonium-mac) (MIT): the breakpoint fix and the base scripts. `scripts/run.sh` and `scripts/run-lan.sh` are derived from plutonium-mac's `run.sh`.
- [3Shain/dxmt](https://github.com/3Shain/dxmt) (MIT): Direct3D 11 to Metal translation.
- [CodeWeavers](https://www.codeweavers.com) / [Wine](https://www.winehq.org): the Wine source code in CrossOver.
- [Plutonium](https://plutonium.pw): the BO2 client.

Unofficial project, not affiliated with Activision, Plutonium, CodeWeavers or Apple. Do not distribute the game files.

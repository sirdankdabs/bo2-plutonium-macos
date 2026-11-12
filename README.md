# Black Ops II + Plutonium on macOS (Apple Silicon)

Play **Call of Duty: Black Ops II** with **Plutonium** (Zombies and Multiplayer, online and LAN) on an Apple Silicon Mac, without a virtual machine.

Tested on a MacBook Pro with an M1 Pro: Zombies and Multiplayer launch, online play works after signing in, ~120 FPS, and no shader-compilation stutter.

## What it does

On macOS, Plutonium hangs at `Loading fastfile code_pre_gfx` because it uses x86 hardware breakpoints, which Rosetta 2 does not support. This project combines and automates:

1. **[crossover-rosetta-patches](https://github.com/LuidgiAlt/crossover-rosetta-patches)** (LuidgiAlt): Wine patches that emulate those breakpoints and remove stalls. They are built from CrossOver 26.3's public source code.
2. **[plutonium-mac](https://github.com/LuidgiAlt/plutonium-mac)** (LuidgiAlt): scripts that create a copy of CrossOver's runtime with the patches, plus a separate Wine prefix. CrossOver.app itself is not modified.
3. **[DXMT](https://github.com/3Shain/dxmt) v0.80** (Direct3D 11 → Metal), rebuilt with an extra patch (`patches/dxmt-async-pipeline-v0.80.patch`): while a shader is still compiling, that draw is skipped for a moment instead of freezing the frame (like DXVK-async). No more stutter when entering new areas.
4. An offline **LAN** launcher (no account needed) and fixes to the original scripts.
5. **[plutonium-mac-aio](https://github.com/LuidgiAlt/plutonium-mac-aio)'s engine** (LuidgiAlt, v0.2.1) to play: the same CrossOver 26.3 Wine and breakpoint patches, plus an **x87 accelerator**. BO2 does its physics and effects in x87 maths, which Rosetta translates slowly; with it, frame rates hold up when zombies and effects fill the screen (see below). The CrossOver runner from step 2 still builds the prefix.
6. **Controller vibration without input delay** (`patches/xinput`): Wine's `XInputSetState` wrote every vibration change to the controller synchronously while holding the lock its input-reading thread needs, so stick and button input reached the game late whenever it rumbled (every shot). The patched `xinput1_3.dll` (built from CrossOver 26.3's Wine source with `0001-xinput-async-vibration.patch`) sends vibration from its own thread, outside that lock, and only the newest value when several arrive during a write. `RUMBLE_FIX=0` puts Wine's original back.
7. Launcher tweaks: macOS Game Mode declaration, raw mouse input, no stick turn-rate acceleration and a smaller stick deadzone, no in-game mouse acceleration, the game's size kept within the display's, DXMT frame pacing at the display's refresh rate, and a `settings.conf` file for options.

### Measured (M1 Pro, 1080p, 160 Hz display with vsync, Nuketown Zombies, Metal HUD)

| | 20 s | 35 s | 50 s (more zombies) |
|---|---:|---:|---:|
| CrossOver runner, windowed, no x87 acceleration | 160 FPS | 160 FPS | **86 FPS** |
| aio engine with x87 acceleration (`run-bo2.sh`) | 160 FPS | 160 FPS | **160 FPS** |

The GPU needs ~4-5 ms per frame either way: the game is limited by the CPU work Rosetta translates.

It does not include any game, Plutonium or CrossOver files.

## Requirements

- An **Apple Silicon** Mac (M1 or later) running macOS 15 or later.
- **Rosetta 2**: `softwareupdate --install-rosetta --agree-to-license`
- **Xcode Command Line Tools**: `xcode-select --install`
- **[Homebrew](https://brew.sh)**.
- **[CrossOver](https://www.codeweavers.com/crossover) 26.3** (build 26.3.0.39832) installed in `/Applications`. The installer copies its Wine runtime; you never need to open CrossOver itself. The free trial is enough to install it, and this setup was tested with the trial version. Using CrossOver after the trial is subject to CodeWeavers' license terms.
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
| `Play Zombies Declassified (LAN).command` | Offline Zombies with the Zombies Declassified mod (see below). |
| `Close BO2.command` | Stops everything running in Wine if something hangs. |
| `Experimental - Play Campaign.command` | **Untested.** Starts the campaign (`t6sp.exe`), see below. |

To set your LAN player name, create a `name.txt` file next to the `.command` files with your name on the first line.

If macOS blocks a `.command` file the first time: right-click it → **Open**.

## Experimental: campaign

Plutonium has no Black Ops II campaign, so `Experimental - Play Campaign.command` runs the campaign executable directly from your game folder (`t6sp.exe`), with the same patched Wine and DXMT, without Plutonium.

- **It has not been tested**: the author's copy of the game has no campaign files. If you try it, please open an issue saying whether it worked.
- You need the complete campaign files in the game folder (`t6sp.exe` and the campaign maps in `zone/`). Without them, the launcher just prints a message and exits without stopping anything.
- The launcher runs the executable as it is. If your `t6sp.exe` needs Steam to start, Steam for Windows must be installed and running in the same Wine prefix.
- If your campaign executable has another name, start it from Terminal: `SP_EXE=name.exe "./Experimental - Play Campaign.command"`.
- Log: `build/logs/campaign.log`.

## Zombies Declassified (BO1's zombies maps in BO2)

[Zombies Declassified](https://github.com/Logo-2K/zombies-declassified) (Logo-2K) is a Plutonium mod that ports Black Ops II's unreleased "DLC 5": Nacht der Untoten, Verrückt, Shi No Numa, Der Riese, Kino der Toten, "Five", Ascension, Shangri-La and Moon. It needs the full game with all DLC.

```bash
scripts/zombies-declassified.sh           # install or update (~9 GB)
scripts/zombies-declassified.sh verify    # check the installed files
```

The script runs the mod's own installer (`zdinstall.py`, from its latest release) with this setup's folders: every file is checked against the release's SHA-256, and anything replaced is backed up under `~/.zombies-declassified/backups`. This repository contains no mod files.

To play: `Play Zombies Declassified (LAN).command` (offline; pick the map in the mod's menu), or online from the Plutonium launcher, then **Mods → dlc5** in the game. Tested on an M1 Pro: Kino der Toten loads and runs at ~160 FPS.

## Troubleshooting

- **Crash with `sample count 8 is not supported`**: Apple GPUs support at most 4x MSAA. Lower anti-aliasing in the game (the scripts already clamp it in the config files).
- **A long pause while a map loads**: this is normal (it happens on Windows too).
- **Going back to stock DXMT** (without the async patch): set `ASYNC=0` in `settings.conf`.
- **A crash that goes away with `X87=0`**: play with `X87=0` in `settings.conf`.
- **Logs**: `logs/`, `build/logs/` and `build/plutonium-mac/prefix/drive_c/users/crossover/AppData/Local/Plutonium/console.log`.

## Options

Set them in `settings.conf` (read by every `.command` file, Play Online included) or as environment variables for `run-bo2.sh`. The full list is at the top of `run-bo2.sh`:

- `MAXFPS=<n>`: frame-rate cap (default: the display's refresh rate; `0`: none).
- `X87=0`: turn the x87 acceleration off (only if a crash goes away without it).
- `ASYNC=0`: turns off background shader compilation.
- `WINDOWED=1` / `FULLSCREEN=1`: display mode. BO2 also keeps it in its hardware profile: set it in the game's options.
- `RUMBLE_FIX=0`: Wine's original xinput (vibration then delays controller input).
- `AIM_ACCEL=1`: keep the game's stick turn-rate acceleration (off by default: it felt like input lag). `STICK_DEADZONE=<n>`: stick deadzone (default `0.08`; the game's is `0.2`).
- `RAW_INPUT=0`, `GAMEMODE=0`, `HUD=1` (Metal performance HUD), `SHOWFPS=1`.
- `LAZY_EXEC=0`, `SOCKFIX=0`: turn off performance patches (for comparison).

The older CrossOver-runner launchers (`build/plutonium-mac/run.sh`, `run-lan.sh`) still work for comparison.

## Credits and licenses

- [Logo-2K/zombies-declassified](https://github.com/Logo-2K/zombies-declassified) (GPL-3.0): the mod `scripts/zombies-declassified.sh` installs.
- [LuidgiAlt/plutonium-mac-aio](https://github.com/LuidgiAlt/plutonium-mac-aio): the engine `run-bo2.sh` plays on (x87 acceleration), downloaded by `scripts/setup-aio.sh` and checked by SHA-256.
- [LuidgiAlt/crossover-rosetta-patches](https://github.com/LuidgiAlt/crossover-rosetta-patches) (LGPL-2.1+) and [LuidgiAlt/plutonium-mac](https://github.com/LuidgiAlt/plutonium-mac) (MIT): the breakpoint fix and the base scripts. `scripts/run.sh` and `scripts/run-lan.sh` are derived from plutonium-mac's `run.sh`.
- [3Shain/dxmt](https://github.com/3Shain/dxmt) (MIT): Direct3D 11 to Metal translation.
- [CodeWeavers](https://www.codeweavers.com) / [Wine](https://www.winehq.org): the Wine source code in CrossOver.
- [Plutonium](https://plutonium.pw): the BO2 client.

Unofficial project, not affiliated with Activision, Plutonium, CodeWeavers or Apple. Do not distribute the game files.

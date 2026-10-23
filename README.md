# Black Ops II + Plutonium en macOS (Apple Silicon)

Juega **Call of Duty: Black Ops II** con **Plutonium** (Zombies y Multijugador, online y LAN) en un Mac con Apple Silicon, sin máquina virtual.

Probado en un MacBook Pro M1 Pro: Zombies y Multijugador abren, el online funciona con inicio de sesión, ~120 FPS y sin tirones de compilación de shaders.

> *English summary at the bottom.*

## Qué hace

Plutonium se cuelga en macOS en `Loading fastfile code_pre_gfx` porque usa breakpoints por hardware que Rosetta 2 no soporta. Este proyecto junta y automatiza:

1. **[crossover-rosetta-patches](https://github.com/LuidgiAlt/crossover-rosetta-patches)** (LuidgiAlt): parches de Wine que emulan esos breakpoints y quitan tirones. Se compilan desde el código fuente público de CrossOver 26.3.
2. **[plutonium-mac](https://github.com/LuidgiAlt/plutonium-mac)** (LuidgiAlt): scripts que crean una copia del runtime de CrossOver con los parches y un prefijo de Wine propio. CrossOver.app no se modifica.
3. **[DXMT](https://github.com/3Shain/dxmt) v0.80** (Direct3D 11 → Metal), recompilado con un parche propio (`patches/dxmt-async-pipeline-v0.80.patch`): cuando un shader aún se está compilando, se salta ese dibujo un instante en vez de congelar la imagen (como DXVK-async). Adiós a los tirones al entrar en zonas nuevas.
4. Un lanzador **LAN** (sin cuenta) y arreglos a los scripts originales.

No incluye archivos del juego, de Plutonium ni de CrossOver.

## Requisitos

- Mac con **Apple Silicon** (M1 o posterior) y macOS 15 o posterior.
- **Rosetta 2**: `softwareupdate --install-rosetta --agree-to-license`
- **Xcode Command Line Tools**: `xcode-select --install`
- **[Homebrew](https://brew.sh)**.
- **[CrossOver](https://www.codeweavers.com/crossover) 26.3** (versión 26.3.0.39832) instalado en `/Applications`. Se usa su runtime; necesitas una licencia válida de CrossOver.
- Tu copia de **Black Ops II** (carpetas `zone/`, `sound/`, `video/`, …) con **`plutonium.exe`** dentro de la misma carpeta. Descarga `plutonium.exe` de [plutonium.pw](https://plutonium.pw).
- Unos 10 GB libres para compilar.
- Para jugar online: una cuenta de [Plutonium](https://forum.plutonium.pw).

## Instalación

1. Abre Terminal y entra en la carpeta del juego (la que tiene `plutonium.exe`):
   ```bash
   cd "/ruta/a/Call of Duty Black Ops II"
   ```
2. Descarga este proyecto dentro de esa carpeta:
   ```bash
   git clone https://github.com/sirdankdabs/bo2-plutonium-macos.git
   ```
3. Ejecuta el instalador (tarda 15–30 minutos la primera vez; compila Wine y DXMT):
   ```bash
   cd bo2-plutonium-macos && ./install.sh
   ```
   Si el proyecto está en otro sitio, pásale la carpeta del juego: `./install.sh "/ruta/a/Call of Duty Black Ops II"`.
4. Al final se abre el instalador de Plutonium: espera a que descargue y aparezca el launcher. Puedes cerrarlo o iniciar sesión ya.

## Jugar

Haz doble clic en los archivos de la carpeta `bo2-plutonium-macos`:

| Archivo | Qué hace |
|---|---|
| `Plutonium Online.command` | Abre el launcher de Plutonium. Inicia sesión, elige Black Ops II, en **Set up** selecciona la carpeta del juego (en Wine aparece como `Z:\ruta\a\Call of Duty Black Ops II`; el instalador te muestra la ruta exacta) y pulsa **Play**. |
| `Jugar Zombies (LAN).command` | Zombies sin conexión, sin cuenta. |
| `Jugar Multijugador (LAN).command` | Multijugador sin conexión, sin cuenta. |
| `Cerrar BO2.command` | Cierra todo lo que corre en Wine si algo se queda colgado. |

Para cambiar tu nombre en LAN, crea un archivo `name.txt` junto a los `.command` con tu nombre en la primera línea.

Si macOS bloquea un `.command` la primera vez: clic derecho → **Abrir**.

## Problemas comunes

- **Se cierra con `sample count 8 is not supported`**: las GPU de Apple solo soportan hasta 4x MSAA. Baja el antialiasing en el juego (los scripts ya lo corrigen en los archivos de configuración).
- **Alguna pausa larga al cargar un mapa**: es normal (también pasa en Windows).
- **Volver al DXMT original** (sin el parche async): ejecuta los lanzadores con `ASYNC=0`, o copia `build/plutonium-mac/runner/CrossOver/lib/dxmt/i386-windows/d3d11.dll.v080` sobre `d3d11.dll`.
- **Logs**: `build/logs/` y `build/plutonium-mac/prefix/drive_c/users/crossover/AppData/Local/Plutonium/console.log`.

## Opciones

Variables que aceptan los lanzadores (`build/plutonium-mac/run.sh` y `run-lan.sh`):

- `ASYNC=0`: desactiva la compilación de shaders en segundo plano.
- `MAXFPS=60`: limita los FPS.
- `WINDOWED=1`: modo ventana (activado en los `.command`).
- `LAZY_EXEC=0`, `SOCKFIX=0`: desactivan parches de rendimiento (para comparar).

## Créditos y licencias

- [LuidgiAlt/crossover-rosetta-patches](https://github.com/LuidgiAlt/crossover-rosetta-patches) (LGPL-2.1+) y [LuidgiAlt/plutonium-mac](https://github.com/LuidgiAlt/plutonium-mac) (MIT): el arreglo de los breakpoints y los scripts base. `scripts/run.sh` y `scripts/run-lan.sh` derivan de `run.sh` de plutonium-mac.
- [3Shain/dxmt](https://github.com/3Shain/dxmt) (MIT): traducción de Direct3D 11 a Metal.
- [CodeWeavers](https://www.codeweavers.com) / [Wine](https://www.winehq.org): el código fuente de Wine en CrossOver.
- [Plutonium](https://plutonium.pw): el cliente de BO2.

Proyecto no oficial, sin relación con Activision, Plutonium, CodeWeavers ni Apple. No distribuyas los archivos del juego.

---

## English summary

Plays Black Ops II with Plutonium (online and LAN) on Apple Silicon Macs. Requirements: CrossOver 26.3 (build 26.3.0.39832), Rosetta 2, Xcode Command Line Tools, Homebrew, and your BO2 folder with `plutonium.exe` in it. Clone this repo into the game folder and run `./install.sh`; it builds LuidgiAlt's Rosetta hardware-breakpoint Wine patches from CrossOver's public sources, sets up a separate runner/prefix (CrossOver.app is not modified), installs DXMT v0.80 rebuilt with an async-pipeline patch that skips draws while Metal pipelines compile instead of stalling, and runs the Plutonium installer. Then double-click `Plutonium Online.command` or the LAN launchers.

# Bloody Roar II Recompiled

Static recompilation of **Bloody Roar II** for the Sony PlayStation, built on
[psxrecomp](https://github.com/mstan/psxrecomp) and
[recomp-ui](https://github.com/mstan/recomp-ui), targeting a native Windows PC
port.

| | |
|---|---|
| Players | 2 |
| Regions | Europe (SLES-01722) + USA (SCUS-94424) |
| Publisher | Virgin Interactive (EU) / Sony (US) |
| Year | 1998 (US) / 1999 (EU) |

## ⚖️ Copyright / Legal

**The game and its data are NOT distributed.** You must supply the files from
your **legally obtained** copy of *Bloody Roar II* (the `.bin` / `.cue` disc
images). This project follows the "copyright-friendly" convention of the
static-recompilation community (e.g. `mstan`'s recomp projects): the code,
launcher and tools are distributed; **the game's copyrighted content is not**.

- See `baserom.md` for the exact file identity (size and checksums) of both
  regions and how to obtain the dumps.
- The recompiled code (`generated/`) is generated **locally** from your discs
  and is **never committed** to the repository.
- Disc images under `disc/` are gitignored and must never be committed. Retail
  BIOS dumps are not redistributed; OpenBIOS is used for Generate unless you
  supply your own SCPH locally.

Unofficial, non-commercial, research and preservation project. Not affiliated
with or endorsed by Hudson Soft, Sony Computer Entertainment, Virgin
Interactive, or any rightsholder of Bloody Roar.

## Releases (v0.5.0)

Each release ships **both regions as separate self-contained zips** — drop your
legally owned disc image beside the folder, double-click the exe and play:

- `BloodyRoar2-EU-v0.5.0.zip` → Europe `BloodyRoar2_Recompiled.exe` (SLES-01722)
- `BloodyRoar2-US-v0.5.0.zip` → USA `BloodyRoar2_Recompiled_USA.exe` (SCUS-94424)

No disc data, BIOS or pre-generated C is included (see Copyright above). The
setup-host package (optional) lets players Generate & rebuild from source via the
in-app wizard.

## Estructura de carpetas

```
BloodyRoar2Recomp/
├── disc/                # NO incluido. Tu copia legal del juego (.bin/.cue) — ver baserom.md
├── psxrecomp/           # Runtime + recompiler (submodule)
├── recomp-ui/           # Launcher UI (submodule)
├── mods/                # Manifiestos .psxmod de los mods
├── generated/           # NO incluido. Código recompilado generado localmente
├── seeds/               # Seeds de primera pasada de los boot EXE (EU + US)
├── tools/               # Utilidades (sync_symbols.py)
├── assets/              # Icono / PNG de la app
└── scripts/             # Packager
```

## Dual-region build

Both regions coexist in one repo. Each generates its own `generated/<serial>_*.c`
set and builds its own native exe:

| Region | Serial | Config | Seeds | Build target | EXE |
|--------|--------|--------|-------|--------------|-----|
| Europe | SLES-01722 | `game.toml` | `seeds/ghidra_funcs.txt` | `psx-runtime` | `BloodyRoar2_Recompiled` |
| USA | SCUS-94424 | `game_us.toml` | `seeds/ghidra_funcs_us.txt` | `psx-runtime-us` | `BloodyRoar2_Recompiled_USA` |

## Quick start (dev)

```bash
git submodule update --init --recursive
./psxrecomp/tools/ci/build_emitters.sh
python3 psxrecomp/psxrecomp_cli.py generate \
  --config game.toml --project-root . --disc disc/Bloody\ Roar\ 2\ -\ Bringer\ of\ the\ New\ Age\ \(Europe\).cue
python3 psxrecomp/psxrecomp_cli.py generate \
  --config game_us.toml --project-root . --disc disc/Bloody\ Roar\ II\ \(USA\).cue
cmake -S . -B build-release -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-release --target psx-runtime
cmake --build build-release --target psx-runtime-us
```

Generate both regions, then build both targets (or just the one you want).

## Mods

The Bloody Roar II builds ship a **curated** mod catalog. The framework's
Final Bout-specific `psx.enhancement.custom-combat` is excluded, and the
generic framework `psx.enhancement.widescreen` is replaced by a
**from-scratch** per-title widescreen (`br2.enhancement.widescreen`). Only
generic framework mods that make sense for this title remain (cd-speed,
fast-loading, pgxp).

## Widescreen (from scratch)

`br2.enhancement.widescreen` (in `mods/preloaded/packages/`) widens the 3D
fight camera to 16:9 / 21:9 instead of stretching. It follows the psxrecomp
enhancement pattern used by Ape Escape / Tomba (mstan): the display aspect is
selected from the mod package, and the actual FOV widening is declared as
per-title codegen sites in `game.toml` / `game_us.toml` (`[widescreen]` /
`[widescreen.cull]`).

- **`gte_game_mode = true`** — fights render RTPS/RTPT projections; 2D menus /
  FMVs stay pillarboxed 4:3.
- **`squash = true`** — GTE X-squash around OFX + final stretch (the
  DuckStation/Beetle hack, applied in the GTE library). Verified safe: BR2
  reads back projected SXY only inside the render-funnel cull that
  `auto_screen_x` widens.
- **`[widescreen.cull] auto_screen_x = true`, `screen_w_imms = [0x200]`,
  `screen_h_imms = [0x1E0]`** — BR2's screen-extent reject signature
  (`sltiu ...,0x200` + `sltiu ...,0x1E0`) in the triangle render funnels
  (0x8018A59C family), overriding the Tomba/Ape defaults.

The cull sites and game-mode gating were derived from disassembly of
SLES-01722 / SCUS-94424 (see DuckStation's `0x1333` projection-width cheat for
ground truth). The framework enhancement infrastructure (GTE X-squash /
native-wide compositor, `psx_mod_set_fixed_display_aspect`) is by
**NovaPowers** (psxrecomp nova-mods); the per-title wiring and BR2 cull sites
are original to this project.

Enable it in the launcher Mods tab (default off; the faithful 4:3 floor).

See **[`WIDESCREEN.md`](WIDESCREEN.md)** for the full technical write-up: how
the FOV widening works, the binary analysis that found the cull sites, and the
credits (NovaPowers framework + mstan methodology + DuckStation ground truth).

## Symbols

Progressive map: `symbols.toml` → `python3 tools/sync_symbols.py` →
`psx_symbols.h` (`PSX_FN_*`). See `psxrecomp/docs/SYMBOLS.md`.

## Framework pins

Submodule gitlinks (`psxrecomp`, `recomp-ui`, nested `recomp-net`,
`retcomm-rbengine`) are authoritative. `framework_pins.txt` is an optional
scaffold snapshot; release CI logs SHAs with `record_pins.sh` but builds
whatever the gitlinks resolve to. Bump submodules deliberately — do not float
on `main`/`master` in release CI.

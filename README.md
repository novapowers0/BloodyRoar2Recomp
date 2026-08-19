# Bloody Roar II Recompiled

**Native PC port of *Bloody Roar II* for the Sony PlayStation (Windows + Linux).**
The game's original MIPS machine code is statically recompiled to C and built
into a standalone executable — this is a real PC port, not an emulator.

[![Release](https://img.shields.io/github/v/release/novapowers0/BloodyRoar2Recomp?sort=semver&style=flat-square&color=orange&label=Release)](https://github.com/novapowers0/BloodyRoar2Recomp/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Windows_|_Linux-0078D6?style=flat-square)](https://github.com/novapowers0/BloodyRoar2Recomp/releases/latest)
[![License](https://img.shields.io/github/license/novapowers0/BloodyRoar2Recomp?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/novapowers0/BloodyRoar2Recomp?style=flat-square&color=yellow)](https://github.com/novapowers0/BloodyRoar2Recomp)
[![Built with](https://img.shields.io/badge/built%20with-psxrecomp-8A2BE2?style=flat-square)](https://github.com/novapowers0/psxrecomp)

| | |
|---|---|
| **Players** | 2 (versus) |
| **Regions** | Europe (SLES-01722) + USA (SCUS-94424) |
| **Publishers** | Virgin Interactive (EU) / Sony Computer Entertainment (US) |
| **Year** | 1998 (US) / 1999 (EU) |
| **Genre** | 3D fighting |
| **Frameworks** | [psxrecomp](https://github.com/novapowers0/psxrecomp) + [recomp-ui](https://github.com/mstan/recomp-ui) |

---

## How to play

1. **Grab a release** — download the zip for your region and OS from
   [Releases](https://github.com/novapowers0/BloodyRoar2Recomp/releases/latest)
   (Windows `BloodyRoar2-EU-v0.5.0.zip` / `BloodyRoar2-US-v0.5.0.zip`, or the
   `...-Linux-v0.5.0.zip` variants).
2. **Unzip anywhere** — each zip is self-contained (executable, OpenBIOS,
   launcher assets and mods included).
3. **Add your disc image** — put your legally owned *Bloody Roar II* `.bin`/`.cue`
   (or `.iso` / `.chd`) image beside the folder. The launcher asks for it on
   first run and remembers it.
4. **Play**: double-click the `.exe` on Windows, or `./BloodyRoar2_Recompiled`
   (chmod +x first) on Linux. A retail `SCPH-1001.BIN` BIOS next to the
   executable is used if present; otherwise the bundled OpenBIOS is used.

No Python, compiler or setup step is needed to **play** — the recompiled game is
already compiled inside the executable.

> Each region is a different disc image, so each zip only works with its own
> region's disc. They are **not** interchangeable.

---

## Mods

Enable them on the launcher's **Mods** tab. All default to **off**, keeping the
authentic experience — turn on only what you want.

| Mod | What it does | Default |
|---|---|---|
| `br2.enhancement.widescreen` | **Real widescreen** (16:9 / 21:9 / Adaptive): widens the 3D fight camera to reveal more of the arena instead of stretching. 2D menus and FMVs stay faithful 4:3. Authored from scratch for Bloody Roar II. | Off |
| `br2.enhancement.performance` | **Intro FMV skip**: ends the intro movies the game's own way the instant they are detected, so boot reaches the title/attract screen sooner. 2D copyright logos are unaffected. | Off |
| `psx.enhancement.cd-speed` | **CD Speed**: shortens load times by speeding up the emulated CD drive — without speeding the game up, so timing-based play is not disturbed. | Off |
| `psx.enhancement.fast-loading` | **Fast Loading**: accelerates the wall-clock pacing of loads. Safe host-side accelerator; the game itself never desyncs. | Off |
| `psx.enhancement.pgxp` | **PGXP Precision**: sub-pixel vertex precision + perspective-correct texturing. Stops polygon wobble and floor/texture warping. Needs supersampling ≥ 2 to be visible. | Off |

The catalog is **curated**: the framework's Final Bout-specific
`psx.enhancement.custom-combat` and the generic `psx.enhancement.widescreen`
stub are excluded from this title.

---

## Widescreen (from scratch)

The widescreen mod widens the **3D fight camera** (not a stretch) using the
psxrecomp enhancement pattern: a GTE X-squash around OFX plus a final present
stretch, applied inside the runtime's GTE library so every renderer sees it
uniformly.

- Fights render hundreds of RTPS/RTPT projections → the GTE-activity detector
  gates widening to 3D gameplay, and genuine 2D screens stay pillarboxed 4:3.
- Bloody Roar II's own screen-extent cull signature (`sltiu ...,0x200` paired
  with `sltiu ...,0x1E0`) is widened at codegen time, so the game's geometry
  culling stays aligned with the visible frame.
- Verified safe to squash: the game reads projected SXY only inside the render
  funnels that are widened — no AI/UI readback to corrupt.

Read **[`WIDESCREEN.md`](WIDESCREEN.md)** for the full technical write-up: the
binary analysis, how the cull sites were found, and credits (NovaPowers
framework + mstan methodology + DuckStation ground truth).

---

## Releases

Each release ships **both regions as separate self-contained zips** for
**Windows** and **Linux**. All are ready-to-play: the recompiled game code is
compiled inside the binary — download, unzip, drop your legally owned disc
image beside it and pick it in the launcher.

| File | OS | Region | Executable | Disc |
|---|---|---|---|---|
| `BloodyRoar2-EU-v0.5.0.zip` | Windows | Europe | `BloodyRoar2_Recompiled.exe` | SLES-01722 |
| `BloodyRoar2-US-v0.5.0.zip` | Windows | USA | `BloodyRoar2_Recompiled_USA.exe` | SCUS-94424 |
| `BloodyRoar2-EU-Linux-v0.5.0.zip` | Linux | Europe | `BloodyRoar2_Recompiled` | SLES-01722 |
| `BloodyRoar2-US-Linux-v0.5.0.zip` | Linux | USA | `BloodyRoar2_Recompiled_USA` | SCUS-94424 |

No disc data, retail BIOS or pre-generated C is included — you supply your
legally owned disc image (see [Copyright](#-copyright--legal)).

---

## For developers

### Dual-region build

Both regions coexist in this repo. Each generates its own
`generated/<serial>_*.c` set and builds its own native exe:

| Region | Serial | Config | Seeds | Build target | EXE |
|---|---|---|---|---|---|
| Europe | SLES-01722 | `game.toml` | `seeds/ghidra_funcs.txt` | `psx-runtime` | `BloodyRoar2_Recompiled` |
| USA | SCUS-94424 | `game_us.toml` | `seeds/ghidra_funcs_us.txt` | `psx-runtime-us` | `BloodyRoar2_Recompiled_USA` |

### Quick start (dev)

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

### Linux builds

The whole stack is multi-platform (SDL windowing/audio, OpenGL + Vulkan
renderers, POSIX sockets). Two Linux CI workflows:

- [`.github/workflows/linux-build.yml`](.github/workflows/linux-build.yml) —
  builds a Linux **setup-host** (launcher + Generate & rebuild) on every push.
- [`.github/workflows/linux-full-build.yml`](.github/workflows/linux-full-build.yml)
  — builds the full **ready-to-play** Linux binaries (the release zips above)
  from the game's generated C, injected from a private repo secret.

Building the game executable on Linux uses the same flow as the dev quick
start; deps on Debian/Ubuntu:

```bash
sudo apt install build-essential cmake ninja-build pkg-config \
     libsdl2-dev libgl1-mesa-dev libvulkan-dev libxtst-dev glslc
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-linux --target psx-runtime psx-runtime-us
```

CI never ships game C — the recompiled game code is generated locally by each
player from their legally owned disc (the full-build workflow injects it from
the private `generated` repo only at build time).

### Folder structure

```text
BloodyRoar2Recomp/
├── disc/                # NOT included. Your legal copy of the game (.bin/.cue) — see baserom.md
├── psxrecomp/           # Runtime + recompiler (submodule)
├── recomp-ui/           # Launcher UI (submodule)
├── mods/                # Curated mod catalog (manifests .psxmod)
├── src/mods/            # Per-title mod plugins (widescreen + FMV skip)
├── generated/           # NOT included. Recompiled C generated locally from your discs
├── seeds/               # First-pass seeds of the boot EXEs (EU + US)
├── tools/               # Utilities (sync_symbols.py)
├── assets/              # App icon / PNG
└── scripts/             # Packager
```

### Symbols

Progressive map: `symbols.toml` → `python3 tools/sync_symbols.py` →
`psx_symbols.h` (`PSX_FN_*`). See `psxrecomp/docs/SYMBOLS.md`.

### Framework pins

Submodule gitlinks (`psxrecomp`, `recomp-ui`, nested `recomp-net`) are
authoritative. `framework_pins.txt` is an optional scaffold snapshot; release CI
logs SHAs with `record_pins.sh` but builds whatever the gitlinks resolve to.
Bump submodules deliberately — do not float on `main`/`master` in release CI.

---

## Copyright / Legal

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

Released under the **MIT License** — see [`LICENSE`](LICENSE).
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
| **Regions** | One universal executable carries **Europe (SLES-01722) + USA (SCUS-94424)**, plus **Japan/Asia (SLPS-01842)** (experimental, not officially supported); it picks the region from the disc you mount |
| **Publishers** | Virgin Interactive (EU) / Sony Computer Entertainment (US) |
| **Year** | 1998 (US) / 1999 (EU) |
| **Genre** | 3D fighting |
| **Frameworks** | [psxrecomp](https://github.com/novapowers0/psxrecomp) + [recomp-ui](https://github.com/mstan/recomp-ui) |

---

## How to play

1. **Grab a release** — download the zip for your OS from
   [Releases](https://github.com/novapowers0/BloodyRoar2Recomp/releases/latest)
   (Windows `BloodyRoar2-v0.7.1.zip` or the `BloodyRoar2-linux-x64-0.7.1.zip` variant).
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

> **One executable, any supported region.** The same binary runs the European,
> USA and Japan/Asia discs — it detects which one you mounted and runs that
> region's code. Japan/Asia is included for testing but is **not officially
> supported** yet (see [Regions](#regions)).

---

## Regions

This port ships a single **universal** executable. The recompiled code for every
region is linked into it under its own symbol namespace; at boot the runtime reads
the mounted disc's `SYSTEM.CNF` boot EXE and runs that region's code. You do not
pick a build — you pick your disc.

| Region | Serial | Boot EXE | Status |
|---|---|---|---|
| Europe | SLES-01722 | `SLES_017.22` | **Supported** |
| USA | SCUS-94424 | `SCUS_944.24` | **Supported** |
| Japan/Asia | SLPS-01842 | `SLPS_018.42` | Experimental (bring-up) |

An unsupported region's disc fails with an actionable identity error rather than
falling through to another region's code.

---

## Mods

Enable them on the launcher's **Mods** tab. All default to **off**, keeping the
authentic experience — turn on only what you want.

| Mod | What it does | Default |
|---|---|---|
| `br2.enhancement.widescreen` | **Real widescreen** (16:9 / 21:9 / Adaptive): widens the 3D fight camera to reveal more of the arena instead of stretching. 2D menus and FMVs stay faithful 4:3. Authored from scratch for Bloody Roar II. | Off |
| `br2.enhancement.performance` | **Intro FMV skip**: ends the intro movies the game's own way the instant they are detected, so boot reaches the title/attract screen sooner. 2D copyright logos are unaffected. | Off |
| `br2.enhancement.unlock-all` | **Unlock All Content**: unlocks Gado, Shen Long, all custom options, movies and pictures without completing modes (guest-RAM flag rewrite, like the classic GameShark codes). Skipped in netplay sessions. | Off |
| `br2.enhancement.turbo` | **Turbo Mode**: runs the game at an arcade-style turbo cadence (75/120 Hz or uncapped) by re-pacing the guest VBlank. Gameplay speed scales with the rate, like the classic arcade Turbo editions. | Off |
| `psx.enhancement.cd-speed` | **CD Speed**: shortens load times by speeding up the emulated CD drive — without speeding the game up, so timing-based play is not disturbed. | Off |
| `psx.enhancement.fast-loading` | **Fast Loading**: accelerates the wall-clock pacing of loads. Safe host-side accelerator; the game itself never desyncs. | Off |
| `psx.enhancement.pgxp` | **PGXP Precision**: sub-pixel vertex precision + perspective-correct texturing. Stops polygon wobble and floor/texture warping. Needs supersampling ≥ 2 to be visible. | Off |

The catalog is **curated**: the framework's Final Bout-specific
`psx.enhancement.custom-combat` and the generic `psx.enhancement.widescreen`
stub are excluded from this title.

---

## Netplay (online versus)

Bloody Roar II supports **2-player online versus** through the launcher's
**Netplay** button, powered by the framework's rollback-capable
[recomp-net](https://github.com/TechnicallyComputers/recomp-net) stack
(delay-sync by default; rollback where the session allows). The public lobby
runs at `netplay.retcomm.net`.

- **How to play online**: both players run the **same release** (same region +
  OS), open the launcher, click **Netplay** → **Create** (host) or **Join**
  (enter the host's lobby), seat both players, and start. Or use **LAN /
  Direct IP** for a peer-to-peer session on the same network.
- **Same disc required**: netplay is dump-strict — every peer must mount the
  same region's `.cue`/`.bin` image geometry. The online gate verifies the TOC
  fingerprint and track count before a session can start, and each region has its
  own fingerprint, so an EU host and a US guest are never matched. The lobby also
  advertises the mounted region in the game title.
- **Same version pin**: peers must run the same release build so generated code
  and the netplay protocol stay compatible. Mixing regions (EU vs US) is not
  supported in one session.
- **Mods follow the host**: the host's enabled mod plan is published on the
  lobby and every peer **adopts that plan at launch** — a peer's own offline mod
  selection is not merged in — so the match simulates identically. Guests that
  lack a host-selected package are warned before the session starts. The
  unlock-all mod is skipped in netplay sessions.

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

Every release ships the game as **2 self-contained, ready-to-play zips** — one
per OS, each carrying every supported region. No setup, compiler or Python is
needed: the recompiled game code is already compiled inside the executable.

Just download the zip for your OS, unzip it anywhere, drop your legally owned
disc image beside it and pick it in the launcher.

| Zip | OS | Regions | Executable |
|---|---|---|---|
| `BloodyRoar2-v0.7.1.zip` | Windows | EU + USA (+ Japan exp.) | `BloodyRoar2_Recompiled.exe` |
| `BloodyRoar2-linux-x64-0.7.1.zip` | **Linux** | EU + USA (+ Japan exp.) | `BloodyRoar2_Recompiled` |

> On Linux, `chmod +x BloodyRoar2_Recompiled` and run it — the zip drops the
> `.exe` extension.

No disc data, retail BIOS or pre-generated C is included — you supply your
legally owned disc image (see [Copyright](#-copyright--legal)).

### v0.7.1 preparation

The release candidate updates the shared `recomp-ui` launcher and refreshes the
Windows/Linux release build and package checks. `psxrecomp` remains pinned to
the newest revision that retains this title's universal-region, curated-mod and
netplay integrations; upstream `master` currently removes those title APIs.
Both full-build workflows create testable, version-stamped artifacts before
publishing.

---

## For developers

### Multi-region build

EU and USA are the shipped regions; Japan/Asia is opt-in. Each region generates
its own `generated/<serial>_*.c` set under a distinct symbol prefix
(`br2eu_` / `br2us_` / `br2jp_`), so all three link into one universal exe.
Isolated per-region targets still exist for bring-up and diffing:

| Region | Serial | Config | Seeds | Build target | EXE |
|---|---|---|---|---|---|
| Europe | SLES-01722 | `game.toml` | `seeds/ghidra_funcs.txt` | `psx-runtime` | `BloodyRoar2_Recompiled` |
| USA | SCUS-94424 | `game_us.toml` | `seeds/ghidra_funcs_us.txt` | `psx-runtime-us` | `BloodyRoar2_Recompiled_USA` |
| Japan/Asia | SLPS-01842 | `game_japan.toml` | `seeds/ghidra_funcs_japan.txt` | `psx-runtime-japan` (`-DBR2_BUILD_JAPAN=ON`) | `BloodyRoar2_Recompiled_Japan` |
| **Universal** | all three | `game.toml` (base) | — | `psx-runtime-universal` (`-DBR2_BUILD_UNIVERSAL=ON`) | `BloodyRoar2_Recompiled` |

### Quick start (dev)

```bash
git submodule update --init --recursive
./psxrecomp/tools/ci/build_emitters.sh
# Generate each region you want to link (universal needs all three):
python3 psxrecomp/psxrecomp_cli.py generate --config game.toml        --project-root . --disc disc/<EU>.cue
python3 psxrecomp/psxrecomp_cli.py generate --config game_us.toml     --project-root . --disc disc/<USA>.cue
python3 psxrecomp/psxrecomp_cli.py generate --config game_japan.toml  --project-root . --disc disc/<JP>.cue
# Universal exe (needs EU + USA + Japan generated C present):
cmake -S . -B build-universal -G Ninja -DCMAKE_BUILD_TYPE=Release -DBR2_BUILD_UNIVERSAL=ON
cmake --build build-universal --target psx-runtime-universal
```

`--verify-disc <image>` runs the launcher's disc-verify pass headlessly and prints
the verdict/serial/region, so the universal selection can be checked without a GUI.

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
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Release -DBR2_BUILD_UNIVERSAL=ON
cmake --build build-linux --target psx-runtime-universal
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
├── src/mods/            # Per-title mod plugins (widescreen, FMV skip, unlock-all, turbo)
├── generated/           # NOT included. Recompiled C generated locally from your discs
├── seeds/               # First-pass seeds of the boot EXEs (EU + US + JP)
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
The `recomp-ui` gitlink is updated to `b688ca79109bc3cc30a6f9de66d81ea70f0acf81`;
`psxrecomp` stays on compatible `nova-mods` commit
`219a3627f817c5ad60b852d368c1bebc4f584b71`.

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

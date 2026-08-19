# Required game files

Provide these files locally from your **legally obtained** copy of *Bloody Roar
II* (Europe SLES-01722 and/or USA SCUS-94424) for the Sony PlayStation. **None
of them are distributed by this project.** This document lets you verify you
have the exact files the recompile expects, the same way other static
recompilation projects do (e.g. `baserom.md` in mstan's recomp projects).

## Disc images (`.bin` / `.cue`)

The game is distributed on a single-disc CD-ROM. The recompile reads the data
track (Track 01) as a `.bin` plus its `.cue`.

### Europe (SLES-01722) — primary

- Expected path: `disc/Bloody Roar 2 - Bringer of the New Age (Europe).bin`
- Data track size: **553,651,392 bytes** (553.7 MB)
- MD5: `fb75a0fdf977a3eccc48fdc87286b0ef`
- SHA-1: `c6021ee7817cdd3dba3e2cf8238054a7943aa5be`
- Volume ID: `SLES_01722`
- Serial: `SLES-01722`
- Boot EXE: `SLES_017.22` (load `0x8011E800`, entry `0x80126178`)
- Config: `game.toml`; seeds `seeds/ghidra_funcs.txt`
- Build target: `psx-runtime` → `BloodyRoar2_Recompiled`

### USA (SCUS-94424) — secondary

- Expected path: `disc/Bloody Roar II (USA).bin`
- Data track size: **552,729,408 bytes** (552.7 MB)
- MD5: `fa5b8e192dbfef77fb2fe3416a1b9469`
- SHA-1: `75a13364ae026fe555e9c666c7c3434e5b403cc8`
- Volume ID: `SCUS_94424`
- Serial: `SCUS-94424`
- Boot EXE: `SCUS_944.24` (load `0x8011E800`, entry `0x80126174`)
- Config: `game_us.toml`; seeds `seeds/ghidra_funcs_us.txt`
- Build target: `psx-runtime-us` → `BloodyRoar2_Recompiled_USA`

> The `.bin` / `.cue` are **copyrighted** and are **not distributed** by this
> project. You must dump them yourself from the original PlayStation discs you
> own (a Redump-format dump with a full multi-track cue is recommended). These
> Track-01-only dumps are functional locally; a full multi-track Redump cue is
> required for online multi-track gates.

## Extracting the boot executable (optional, advanced)

The boot EXE `SLES_017.22` / `SCUS_944.24` lives inside the data track. The
`prepare_disc` step of the toolchain extracts it automatically; you normally do
not need to touch it by hand.

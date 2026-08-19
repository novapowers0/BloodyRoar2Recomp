# Bloody Roar II Recomp — Session Summary

## Objective
Crear un puerto nativo PC de "Bloody Roar II" (SLES-01722 Europa / SCUS-94424 USA)
con psxrecomp (fork NovaPowers) + recomp-ui: recompilación dual-región en un solo
repo, widescreen 16:9/21:9 desde cero, mods de calidad de vida (auto-skip de FMVs)
y catálogo de mods curado. Release v0.5.0: dos zips autocontenidos (EU + USA) en el
mismo release.

## Lo conseguido
- **Dual-región**: cada región genera su propio `generated/<serial>_full_*.c` y su
  propio exe (`BloodyRoar2_Recompiled` EU / `BloodyRoar2_Recompiled_USA`).
  Configs separadas: `game.toml` (SLES-01722) y `game_us.toml` (SCUS-94424).
- **Widescreen desde cero** (`br2.enhancement.widescreen`): squash GTE X + present
  stretch, sitios de culling por-título (`[widescreen.cull]` `0x200`/`0x1E0`),
  `gte_game_mode` para mantener 4:3 en 2D/FMV. Ver `WIDESCREEN.md` para el análisis
  completo del binario y créditos (NovaPowers framework + metodología mstan +
  ground truth DuckStation).
- **Intro Skip** (`br2.enhancement.performance`): auto-skip de FMVs vía
  `psx_mod_set_auto_skip_fmv` (API mod-owned del framework).
- **Catálogo curado** en CMakeLists: se descartan `psx.enhancement.custom-combat`
  (específico de Final Bout) y el stub genérico `psx.enhancement.widescreen`;
  quedan `br2.enhancement.widescreen`, `br2.enhancement.performance`, cd-speed,
  fast-loading, pgxp.
- **Fast boot**: `[runtime] bios_hle = true` salta el arranque BIOS/PS1.
- **Release v0.5.0**: `BloodyRoar2-EU-v0.5.0.zip` + `BloodyRoar2-US-v0.5.0.zip`,
  carpetas autocontenidas (exe + OpenBIOS + assets + mods + configs), generadas por
  `scripts/package_release.ps1`.

## Notas técnicas / decisiones
- `squash = true` es seguro en BR2: auditados los 61 `mfc2` de SXY — todos están
  dentro del funnel de culling que `auto_screen_x` ensancha; no hay feed SXY a IA/UI
  (a diferencia de Dragon Ball Final Bout).
- `precise_nclip = true` evita artefactos de clipping wide-edge (arena 3D con mucha
  geometría en los bordes).
- Frame interpolation (120/144/165/240 Hz) se retiró: corrompe la imagen al
  combinarse con el squash-wide de BR2 (bug en la maquinaria GL del framework, no en
  hooks del título). Revisitable cuando el framework lo arregle.

## Estado
- Compilado y verificado en ambos exes (build Release, clang del pack retcomm).
- QA visual pendiente in-game: anclaje de HUD y bordes de backdrop en el
  estiramiento wide (16:9 y 21:9) antes de un release.
- Fast boot HLE activo por defecto (`bios_hle = true`); desactivar para boot BIOS
  auténtico.

## Discos / rutas
- Dumps legales Track-01 en `disc/` (gitignored): EU `Bloody Roar 2 - Bringer of the
  New Age (Europe).bin/.cue`, USA `Bloody Roar II (USA).bin/.cue`. Checksums en
  `baserom.md`. No se distribuyen.
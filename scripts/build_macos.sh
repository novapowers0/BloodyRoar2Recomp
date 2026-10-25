#!/usr/bin/env bash
# build_macos.sh — native macOS (Apple Silicon / Intel) build for Bloody Roar II.
#
# Produces the same setup host the Linux CI ships: a launcher with the first-run
# "Generate & rebuild" wizard. Point it at your legally owned disc and it
# recompiles the game locally, then relaunches the full runtime.
#
# Requirements: Xcode Command Line Tools, CMake 3.20+, Ninja, Python 3.
#   xcode-select --install
#   brew install cmake ninja python3
# Everything else (SDL3, zlib, libchdr, libjuice) is downloaded by CMake and
# SHA256-verified against psxrecomp/third_party/deps.manifest.
#
# Usage:
#   scripts/build_macos.sh              # setup host (no game C)
#   scripts/build_macos.sh --full       # universal EU+USA+JP (needs generated/)
#   scripts/build_macos.sh --usa        # USA target (game_us.toml / SCUS-94424)
#   scripts/build_macos.sh --regen-bios # regenerate the bundled OpenBIOS C
#   scripts/build_macos.sh --clean      # delete build dirs and exit
#   scripts/build_macos.sh --jobs N     # parallel compile jobs
#
# Output: build-macos/BloodyRoar2_Recompiled (+ mods/, bios/, assets/), or
#         build-macos/BloodyRoar2_Recompiled_USA with --usa
#
# Full game C (optional; the wizard does this for you via Generate & rebuild):
#   python3 psxrecomp/psxrecomp_cli.py generate --config game.toml \
#     --project-root . --disc disc/<EU>.cue
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: build_macos.sh is for macOS (uname -s = $(uname -s))" >&2
  echo "       Linux: use the quick-start in README.md; Windows: see README." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BR2_BUILD_DIR:-build-macos}"
EMITTER_BUILD="build-recompiler"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"

FULL=0; USA=0; REGEN_BIOS=0; CLEAN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) FULL=1 ;;
    --usa) USA=1 ;;
    --regen-bios) REGEN_BIOS=1 ;;
    --clean) CLEAN=1 ;;
    --jobs) JOBS="${2:?--jobs needs a number}"; shift 2; continue ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown flag: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

if [[ $CLEAN -eq 1 ]]; then
  rm -rf "$BUILD_DIR" "$EMITTER_BUILD"
  echo "removed $BUILD_DIR/ and $EMITTER_BUILD/"
  exit 0
fi

# --- 0. submodules -----------------------------------------------------------
if [[ ! -f psxrecomp/runtime/runtime.cmake ]]; then
  echo "error: psxrecomp submodule is missing." >&2
  echo "       git submodule update --init --recursive" >&2
  exit 1
fi

# --- 1. recompiler emitters (needed to generate BIOS/game C) -----------------
if [[ ! -x "$EMITTER_BUILD/psxrecomp-game" || ! -x "$EMITTER_BUILD/psxrecomp-bios" ]]; then
  echo "==> building recompiler emitters ($EMITTER_BUILD/)"
  bash psxrecomp/tools/ci/build_emitters.sh --jobs "$JOBS"
fi

# --- 2. bundled OpenBIOS C (MIT; no BIOS dump needed) ------------------------
if [[ $REGEN_BIOS -eq 1 || ! -f psxrecomp/generated/OpenBIOS_full.c ]]; then
  echo "==> generating OpenBIOS C"
  (cd psxrecomp && PSXRECOMP_BIOS_BUILD="../$EMITTER_BUILD" \
     bash tools/regen_bios.sh --config bios/OpenBIOS.toml)
fi

# --- 3. configure ------------------------------------------------------------
CMAKE_ARGS=(-S . -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release)
TARGET="psx-runtime"

# Pin SDL3 through the framework's FetchContent path even when Homebrew ships
# one. Homebrew upgrades move Cellar/<pkg>/<version> paths, which invalidates
# any cached SDL3_DIR/pkg-config include dir and breaks configure
# ("Imported target ... includes non-existent path"); the pinned source build
# is immune, and linking it statically also drops libSDL3 from the binary's
# runtime dependencies.
CMAKE_ARGS+=(-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DPSX_SDL3_FETCH=ON)

# Color-emoji providers (FreeType + HarfBuzz) are optional upstream: when
# present the launcher renders colour glyphs, otherwise it falls back to
# outlines and the build still succeeds. Nothing to configure.

if [[ $FULL -eq 1 ]]; then
  CMAKE_ARGS+=(-DBR2_BUILD_UNIVERSAL=ON)
  TARGET="psx-runtime-universal"
  if ! compgen -G "generated/*.c" >/dev/null; then
    echo "warning: --full needs generated game C (run psxrecomp_cli.py generate" >&2
    echo "         for EU+USA+Japan first; see the header of this script)." >&2
  fi
fi

# USA is a separate target with its own config (game_us.toml), its own generated
# C (SCUS_944.24_*) and its own executable name. The universal target already
# links all regions, so asking for both is a mistake rather than a merge.
if [[ $USA -eq 1 ]]; then
  if [[ $FULL -eq 1 ]]; then
    echo "error: --usa and --full are mutually exclusive" >&2
    exit 2
  fi
  TARGET="psx-runtime-us"
  EXE_NAME="BloodyRoar2_Recompiled_USA"
  if [[ ! -f generated/SCUS_944.24_dispatch.c ]]; then
    echo "error: USA game C is missing. Generate it first:" >&2
    echo "  python3 psxrecomp/psxrecomp_cli.py generate --config game_us.toml \\" >&2
    echo "    --project-root . --disc \"disc/Bloody Roar II (USA).cue\"" >&2
    exit 1
  fi
fi

# --- 4. heal stale Homebrew paths in the CMake cache -------------------------
# pkg-config results are cached with absolute Homebrew Cellar paths. After a
# `brew upgrade`, configure fails on a path that no longer exists (typically
# the optional FreeType/HarfBuzz include dirs). Drop cache lines whose Cellar
# paths are gone and let pkg-config re-resolve; compiled objects survive.
if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
  python3 - "$BUILD_DIR/CMakeCache.txt" <<'PYEOF'
import re, sys
from pathlib import Path

cache = Path(sys.argv[1])
pat = re.compile(r"/opt/homebrew/Cellar/[^/;\s:]+/[^/;\s:]+")
lines = cache.read_text(errors="replace").splitlines(keepends=True)
kept, dropped, poisoned = [], 0, False
for line in lines:
    if any(not Path(p).exists() for p in pat.findall(line)):
        dropped += 1
        poisoned = True
        continue
    kept.append(line)
if poisoned:
    kept = [l for l in kept if not l.startswith("prefix_result:")]
# pkg_check_modules() skips re-resolution while __pkg_config_checked_<PREFIX>
# is cached. Dropping the resolved values without dropping that flag leaves the
# imported target with no include dirs (symptom: "hb.h file not found").
have = {l.split(":", 1)[0] for l in kept if ":" in l}
final = []
for line in kept:
    m = re.match(r"__pkg_config_checked_(\w+):", line)
    if m and (m.group(1) + "_INCLUDE_DIRS") not in have \
            and (m.group(1) + "_CFLAGS") not in have:
        dropped += 1
        continue
    final.append(line)
if dropped:
    cache.write_text("".join(final))
    print(f"    cache: dropped {dropped} stale Homebrew/pkg-config entr(y/ies)")
PYEOF
fi

# --- 5. build ----------------------------------------------------------------
echo "==> configuring ($BUILD_DIR)"
cmake "${CMAKE_ARGS[@]}"

echo "==> building $TARGET"
cmake --build "$BUILD_DIR" --target "$TARGET" -j "$JOBS"

echo
echo "==> done: $BUILD_DIR/${EXE_NAME:-BloodyRoar2_Recompiled}"
echo "    Run it and point the wizard at your legally owned disc (Step 2),"
echo "    then Generate & rebuild (Step 3)."
if [[ $FULL -eq 1 ]]; then
  echo "    Universal target: $BUILD_DIR/BloodyRoar2_Recompiled"
fi
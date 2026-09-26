#!/usr/bin/env bash
# package_release_linux.sh - build self-contained Linux release folders (Option A).
#
# Mirrors the Windows package_release.ps1: takes the ALREADY-COMPILED, fully
# self-contained game executables out of a build dir and assembles two clean,
# distributable folders (Europe + USA), each with everything the runtime needs
# beside the binary (OpenBIOS, assets, mods, game config). The user only drops
# their legally owned .bin/.cue next to the folder and picks it in the launcher.
#
# The game's copyrighted data (.bin/.cue) and the recompiled game C are NOT
# distributed - the recompiled game code is already compiled into the binary.
# No python / cmake / toolchain is needed to run the result.
#
# Usage:
#   scripts/package_release_linux.sh <build-dir> <version>
#
# Writes: dist/BloodyRoar2-EU-linux-x64-<version>.zip and
#         dist/BloodyRoar2-US-linux-x64-<version>.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:?usage: $0 <build-dir> <version>}"
VERSION="${2:?usage: $0 <build-dir> <version>}"
DIST="${ROOT}/dist"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "error: build dir not found: ${BUILD_DIR}" >&2
  exit 1
fi
BUILD_DIR="$(cd "${BUILD_DIR}" && pwd)"

EXE_PATH="${BUILD_DIR}/BloodyRoar2_Recompiled"
VERSION_STAMP="${BUILD_DIR}/psx_game_version.txt"
if [[ ! -f "${EXE_PATH}" ]]; then
  echo "error: universal executable not found: ${EXE_PATH}" >&2
  exit 1
fi
if [[ ! -f "${VERSION_STAMP}" ]]; then
  echo "error: missing game-version stamp beside executable: ${VERSION_STAMP}" >&2
  exit 1
fi
BUILT_VERSION="$(tr -d '[:space:]' <"${VERSION_STAMP}")"
BUILT_VERSION="${BUILT_VERSION#v}"
if [[ "${BUILT_VERSION}" != "${VERSION}" ]]; then
  echo "error: requested version ${VERSION} does not match executable stamp ${BUILT_VERSION}" >&2
  echo "  Reconfigure with -DPSX_GAME_VERSION=${VERSION} and rebuild." >&2
  exit 1
fi

# Resolve an EU/US region config from the build dir or project root.
pick() { # pick <var> <file>
  local var="$1" file="$2"
  if [[ -f "${BUILD_DIR}/${file}" ]]; then
    printf -v "${var}" "%s" "${BUILD_DIR}/${file}"
  elif [[ -f "${ROOT}/${file}" ]]; then
    printf -v "${var}" "%s" "${ROOT}/${file}"
  else
    echo "error: missing config file ${file}" >&2
    exit 1
  fi
}

package() { # package <exe-name> <config-file> <folder-name> <display-name>
  local exe="$1" config="$2" folder="$3" display="$4"
  local out="${DIST}/${folder}"
  local config_src

  rm -rf "${out}"
  mkdir -p "${out}"

  if [[ ! -f "${BUILD_DIR}/${exe}" ]]; then
    echo "error: binary not found: ${BUILD_DIR}/${exe}" >&2
    exit 1
  fi
  cp -a "${BUILD_DIR}/${exe}" "${out}/${exe}"

  # Bundled OpenBIOS (MIT) - staged by the runtime build next to the exe.
  if [[ ! -f "${BUILD_DIR}/bios/openbios.bin" ]]; then
    echo "error: ${BUILD_DIR}/bios/openbios.bin missing (rebuild runtime)" >&2
    exit 1
  fi
  mkdir -p "${out}/bios"
  cp -a "${BUILD_DIR}/bios/openbios.bin" "${out}/bios/openbios.bin"
  cp -a "${BUILD_DIR}/bios/OpenBIOS.LICENSE" "${out}/bios/OpenBIOS.LICENSE"

  # Launcher assets (fonts + images) staged by recomp-ui.
  cp -a "${BUILD_DIR}/assets" "${out}/assets"

  # Curated mod catalog (v4 runtime stages it under mods/bundled).
  mkdir -p "${out}/mods"
  cp -a "${BUILD_DIR}/mods/bundled" "${out}/mods/bundled"

  # Game configs.
  pick config_src "${config}"
  cp -a "${config_src}" "${out}/${config}"
  for extra in game_options.toml keybinds.ini; do
    if [[ -f "${BUILD_DIR}/${extra}" ]]; then
      cp -a "${BUILD_DIR}/${extra}" "${out}/${extra}"
    elif [[ -f "${ROOT}/${extra}" ]]; then
      cp -a "${ROOT}/${extra}" "${out}/${extra}"
    fi
  done

  # Short user-facing README.
  cat > "${out}/README.txt" <<EOF
${display}  -  Bloody Roar II Recompiled (${VERSION})
====================================================

This is a self-contained Linux build: the recompiled game code for every
supported region is compiled inside the ONE executable, so no Python, compiler
or setup step is needed.

ONE EXECUTABLE, ANY SUPPORTED REGION
------------------------------------
The same binary runs the European, USA and Japan/Asia discs. It detects which
disc you mounted and runs that region's code - you do not pick a build.

   - EUROPE      (SLES-01722)  -> supported
   - USA         (SCUS-94424)  -> supported
   - JAPAN/ASIA  (SLPS-01842)  -> experimental (not officially supported)

An unsupported disc fails with a clear identity error instead of running the
wrong region's code.

To play:
  1. Put your legally owned Bloody Roar II disc image somewhere on this
     machine. Supported: .cue/.bin (and .iso / .chd). Note that .ecm files are
     compressed archives - decompress them to a .bin/.cue first (with
     ecm-tools), they are not loadable directly.
  2. Run:  chmod +x ${exe} && ./${exe}
  3. On first run the launcher asks for the disc image and (optionally) a
     BIOS. Select your image and play. A retail SCPH-1001.BIN next to the
     binary is used if present; otherwise the bundled OpenBIOS is used.
     (The launcher needs zenity or kdialog installed for the file picker:
      sudo apt install zenity, or kdialog on KDE.)

Mods (launcher -> Mods tab): widescreen, skip intro FMVs, unlock all content,
turbo mode, CD speed, fast loading and PGXP. All mods are disabled by default.

Linux graphics and audio use the system's OpenGL/Vulkan and SDL dependencies.
On Debian/Ubuntu, install the runtime libraries with:
  sudo apt install libgl1 libvulkan1 libx11-6 libxext6 libxrandr2 libxcursor1 \
    libxfixes3 libxi6 libxss1 libasound2 libpulse0 libudev1 zenity

The game's copyrighted data is not included - supply your own disc image.
EOF

  # Assemble the zip from inside dist/ so paths are relative.
  local zipname="${folder}-linux-x64-${VERSION}.zip"
  ( cd "${DIST}" && zip -qr "${zipname}" "${folder}" )
  echo "Built ${DIST}/${zipname}"
}

mkdir -p "${DIST}"
package "BloodyRoar2_Recompiled" "game.toml" "BloodyRoar2" "Bloody Roar II Recompiled (Universal: EU + USA + Japan)"

echo "Done. Linux release folder under: ${DIST}"
echo "Self-contained - drop a disc image beside it and play."

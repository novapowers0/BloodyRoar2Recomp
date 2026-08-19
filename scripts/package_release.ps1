# package_release.ps1 - build self-contained release folders (Option A).
#
# Takes the ALREADY-COMPILED, self-contained game executables out of
# build-release/ and assembles two clean, distributable folders (Europe + USA),
# each with everything the runtime needs beside the exe (BIOS, assets, mods,
# game config). The user only drops their legally owned .bin/.cue next to the
# folder and picks it in the launcher on first run (the launcher writes
# settings.toml / disc.cfg / input.ini itself).
#
# NOTE: the game's copyrighted data (.bin/.cue) and the recompiled generated
# code are NOT distributed - the exe already has the recompiled code compiled
# in. No python / cmake / toolchain is needed to run the result.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/package_release.ps1
#
# Writes: dist/BloodyRoar2-EU/ and dist/BloodyRoar2-US/ (+ a README.txt each).

$ErrorActionPreference = "Stop"

$Root    = Split-Path -Parent $PSScriptRoot
$Build   = Join-Path $Root "build-release"
$Dist    = Join-Path $Root "dist"
$Version = (Get-Content (Join-Path $Root "VERSION") -ErrorAction SilentlyContinue).Trim()
if (-not $Version) { $Version = "0.1.0" }

if (-not (Test-Path $Build)) {
    Write-Error "build-release/ not found. Build first: cmake --build build-release"
}

function Copy-Tree($src, $dst) {
    # Copy the CONTENTS of $src into $dst (no extra nesting level).
    if (Test-Path $src) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Get-ChildItem -Path $src -Force | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $dst -Recurse -Force
        }
    }
}

function New-ReleaseFolder($exeName, $configName, $folderName, $displayName) {
    $out = Join-Path $Dist $folderName
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $out | Out-Null

    # Executable (self-contained: recompiled game code is compiled in).
    Copy-Item (Join-Path $Build $exeName) (Join-Path $out $exeName) -Force

    # BIOS (OpenBIOS ships; a retail SCPH-1001 beside the exe is also accepted).
    New-Item -ItemType Directory -Force -Path (Join-Path $out "bios") | Out-Null
    Copy-Item (Join-Path $Build "bios\openbios.bin") (Join-Path $out "bios\openbios.bin") -Force
    Copy-Item (Join-Path $Build "bios\OpenBIOS.LICENSE") (Join-Path $out "bios\OpenBIOS.LICENSE") -Force

    # Launcher assets (fonts + images).
    Copy-Tree (Join-Path $Build "assets") (Join-Path $out "assets")

    # Curated mod catalog.
    Copy-Tree (Join-Path $Build "mods\packages") (Join-Path $out "mods\packages")

    # Game configs.
    Copy-Item (Join-Path $Root $configName) (Join-Path $out $configName) -Force
    if (Test-Path (Join-Path $Root "game_options.toml")) {
        Copy-Item (Join-Path $Root "game_options.toml") (Join-Path $out "game_options.toml") -Force
    }
    if (Test-Path (Join-Path $Root "keybinds.ini")) {
        Copy-Item (Join-Path $Root "keybinds.ini") (Join-Path $out "keybinds.ini") -Force
    }

    # Short user-facing README.
    @"
$displayName  -  Bloody Roar II Recompiled ($Version)
====================================================

This is a self-contained build: the recompiled game code is compiled inside
the executable, so no Python, compiler or setup step is needed.

WHICH FOLDER DO I USE?
----------------------
There are TWO separate folders (BloodyRoar2-EU and BloodyRoar2-US) because
each region is a different disc image (Europe SLES-01722 vs USA SCUS-94424).
The recompiler translates the machine code of one specific disc into the
executable, so each exe only works with its own region's disc. They are not
interchangeable.

  - Have the EUROPEAN disc  -> use BloodyRoar2-EU/BloodyRoar2_Recompiled.exe
  - Have the AMERICAN disc  -> use BloodyRoar2-US/BloodyRoar2_Recompiled_USA.exe

To play:
  1. Put your legally owned Bloody Roar II disc image somewhere on this
     machine. Supported: .cue/.bin (and .iso / .chd). Note that .ecm files
     are compressed archives - decompress them to a .bin/.cue first (with
     ecm-tools), they are not loadable directly.
  2. Double-click $exeName.
  3. On first run the launcher asks for the disc image and (optionally) a
     BIOS. Select your image and play. A retail SCPH-1001.BIN next to the
     exe is used if present; otherwise the bundled OpenBIOS is used.

Mods (launcher -> Mods tab): widescreen, skip intro FMVs, CD speed,
fast loading, PGXP.

The game's copyrighted data is not included - supply your own disc image.
"@ | Set-Content -Path (Join-Path $out "README.txt") -Encoding UTF8

    Write-Host "Built $out"
}

New-ReleaseFolder "BloodyRoar2_Recompiled.exe"     "game.toml"    "BloodyRoar2-EU" "Bloody Roar II Recompiled (Europe)"
New-ReleaseFolder "BloodyRoar2_Recompiled_USA.exe" "game_us.toml" "BloodyRoar2-US" "Bloody Roar II Recompiled (USA)"

Write-Host ""
Write-Host "Done. Distribution folders under: $Dist"
Write-Host "Each is self-contained - drop a disc image beside it and play."

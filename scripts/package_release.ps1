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
#   powershell -ExecutionPolicy Bypass -File scripts/package_release.ps1 [-Build build-universal]
#
# Writes: dist/BloodyRoar2/ (+ README.txt) and dist/BloodyRoar2-v<version>.zip.
# The build dir must contain the universal exe (BR2_BUILD_UNIVERSAL=ON,
# target psx-runtime-universal) as BloodyRoar2_Recompiled.exe.

param(
    [string]$Build = "build-universal"
)

$ErrorActionPreference = "Stop"

$Root    = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($Build)) { $Build = Join-Path $Root $Build }
$Dist    = Join-Path $Root "dist"
$Version = (Get-Content (Join-Path $Root "VERSION") -ErrorAction SilentlyContinue).Trim()
if (-not $Version) { $Version = "0.1.0" }

if (-not (Test-Path $Build)) {
    Write-Error "$Build not found. Build first: cmake --build build-universal --target psx-runtime-universal"
}

$ExePath = Join-Path $Build "BloodyRoar2_Recompiled.exe"
if (-not (Test-Path $ExePath)) {
    Write-Error "Universal executable not found: $ExePath"
}
$VersionStamp = Join-Path (Split-Path -Parent $ExePath) "psx_game_version.txt"
if (-not (Test-Path $VersionStamp)) {
    Write-Error "Missing game-version stamp beside the executable: $VersionStamp"
}
$BuiltVersion = (Get-Content -Raw $VersionStamp).Trim().TrimStart("v")
if ($BuiltVersion -ne $Version) {
    Write-Error "VERSION ($Version) does not match executable stamp ($BuiltVersion). Reconfigure with -DPSX_GAME_VERSION=$Version and rebuild."
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

    # Curated mod catalog (v4 runtime stages it under mods/bundled).
    Copy-Tree (Join-Path $Build "mods\bundled") (Join-Path $out "mods\bundled")

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

This is a self-contained build: the recompiled game code for every supported
region is compiled inside the ONE executable, so no Python, compiler or setup
step is needed.

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
     machine. Supported: .cue/.bin (and .iso / .chd). Note that .ecm files
     are compressed archives - decompress them to a .bin/.cue first (with
     ecm-tools), they are not loadable directly.
  2. Double-click $exeName.
  3. On first run the launcher asks for the disc image and (optionally) a
     BIOS. Select your image and play. A retail SCPH-1001.BIN next to the
     exe is used if present; otherwise the bundled OpenBIOS is used.

Mods (launcher -> Mods tab): widescreen, skip intro FMVs, unlock all content,
turbo mode, CD speed, fast loading, PGXP.

The game's copyrighted data is not included - supply your own disc image.
"@ | Set-Content -Path (Join-Path $out "README.txt") -Encoding UTF8

    Write-Host "Built $out"
}

New-ReleaseFolder "BloodyRoar2_Recompiled.exe" "game.toml" "BloodyRoar2" "Bloody Roar II Recompiled (Universal: EU + USA + Japan)"

# Zip the folder for distribution (release asset).
$zipPath = Join-Path $Dist "BloodyRoar2-v$Version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $Dist "BloodyRoar2") -DestinationPath $zipPath -Force
Write-Host "Built $zipPath"

Write-Host ""
Write-Host "Done. Distribution folder + zip under: $Dist"
Write-Host "Self-contained - drop a disc image beside it and play."

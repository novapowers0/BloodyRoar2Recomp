#!/usr/bin/env bash
# package_macos_app.sh — wrap a built runtime into a double-clickable macOS .app.
#
# Why: a bare Mach-O inherits its TCC identity from whatever terminal launches
# it, so Input Monitoring (needed for HID input and for rumble writes) has to be
# granted to the *terminal*, per terminal, forever. A bundle with its own
# CFBundleIdentifier gets the permission once, for the game.
#
# Layout note: the runtime anchors every sidecar file (game*.toml, bios/, mods/,
# assets/, settings.toml, saves/) to the executable's own directory. Inside a
# bundle that directory is Contents/MacOS, so the data lives there rather than
# in Contents/Resources.
#
# Usage:
#   scripts/package_macos_app.sh              # USA build if present, else EU
#   scripts/package_macos_app.sh --usa
#   scripts/package_macos_app.sh --eu
#   scripts/package_macos_app.sh --binary build-macos/BloodyRoar2_Recompiled_USA
#   scripts/package_macos_app.sh --out dist   # default output directory
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BR2_BUILD_DIR:-build-macos}"
OUT_DIR="dist"
REGION="auto"
BINARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --usa) REGION="usa" ;;
    --eu) REGION="eu" ;;
    --binary) BINARY="${2:?--binary needs a path}"; shift 2; continue ;;
    --out) OUT_DIR="${2:?--out needs a directory}"; shift 2; continue ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown flag: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

# --- resolve the binary ------------------------------------------------------
if [[ -z "$BINARY" ]]; then
  case "$REGION" in
    usa) EXE="$BUILD_DIR/BloodyRoar2_Recompiled_USA" ;;
    eu)  EXE="$BUILD_DIR/BloodyRoar2_Recompiled" ;;
    auto)
      if [[ -x "$BUILD_DIR/BloodyRoar2_Recompiled_USA" ]]; then
        EXE="$BUILD_DIR/BloodyRoar2_Recompiled_USA"; REGION="usa"
      else
        EXE="$BUILD_DIR/BloodyRoar2_Recompiled"; REGION="eu"
      fi
      ;;
  esac
else
  EXE="$BINARY"
  case "$EXE" in
    *_USA) REGION="usa" ;;
    *) REGION="eu" ;;
  esac
fi

[[ -x "$EXE" ]] || { echo "error: no executable at $EXE (build first)" >&2; exit 1; }

# --- identity ----------------------------------------------------------------
if [[ "$REGION" == "usa" ]]; then
  APP_NAME="Bloody Roar II Recompiled (USA)"
  BUNDLE_ID="com.fabzter.bloodyroar2recompiled.usa"
else
  APP_NAME="Bloody Roar II Recompiled"
  BUNDLE_ID="com.fabzter.bloodyroar2recompiled"
fi
VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"

APP="$OUT_DIR/$APP_NAME.app"
echo "==> packaging $EXE -> $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# --- payload: executable + everything the runtime resolves next to itself ----
cp "$EXE" "$APP/Contents/MacOS/"
for d in bios mods assets; do
  [[ -d "$BUILD_DIR/$d" ]] && cp -R "$BUILD_DIR/$d" "$APP/Contents/MacOS/"
done
for f in game_us.toml game.toml game_options.toml; do
  [[ -f "$BUILD_DIR/$f" ]] && cp "$BUILD_DIR/$f" "$APP/Contents/MacOS/"
done
# Not copied on purpose: settings.toml, disc.cfg, bios.cfg, saves/ — user state.
# The bundle starts clean and writes its own on first run.

# The launcher resolves its own art/fonts through SDL_GetBasePath(), which is
# bundle-aware on macOS and returns Contents/Resources -- not the exe directory.
# Without this, the launcher silently falls back to a monospace font and shows
# no controller art, while the game itself still runs. Symlink rather than copy:
# one payload, both lookup roots.
if [[ -d "$APP/Contents/MacOS/assets" ]]; then
  ln -sfn ../MacOS/assets "$APP/Contents/Resources/assets"
fi

# --- icon (optional; needs sips + iconutil from Xcode CLT) -------------------
PNG="$BUILD_DIR/assets/psxrecomp.png"
if [[ -f "$PNG" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
  WORK="$(mktemp -d)"
  ICONSET="$WORK/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1 || true
    sips -z "$((size * 2))" "$((size * 2))" "$PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
  done
  if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
    ICON_KEY='    <key>CFBundleIconFile</key>
    <string>AppIcon</string>'
  else
    ICON_KEY=""
    echo "    (icon conversion failed; continuing without an icon)"
  fi
  rm -rf "$WORK"
else
  ICON_KEY=""
fi

# --- Info.plist --------------------------------------------------------------
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$(basename "$EXE")</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Bloody Roar II</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
$ICON_KEY
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" >/dev/null || {
  echo "error: generated Info.plist is not valid" >&2; exit 1; }

# --- ad-hoc signature --------------------------------------------------------
# The executable is already linker-signed by clang, which is enough for the
# loader on Apple Silicon. Signing the *bundle* additionally requires codesign to
# seal every file under Contents/MacOS, and it refuses the mod catalog's dotted
# package directories ("bundle format unrecognized ... br2.enhancement.turbo").
# So: sign the executable explicitly, try the container, and say plainly which of
# the two happened.
EXE_IN_APP="$APP/Contents/MacOS/$(basename "$EXE")"
codesign --force --sign - "$EXE_IN_APP" >/dev/null 2>&1 || true
if codesign --force --sign - "$APP" >/dev/null 2>&1; then
  echo "    signed: ad-hoc (bundle container)"
else
  echo "    signed: ad-hoc executable only — the bundle container stays unsealed"
  echo "            (codesign cannot seal the dotted mod-package directories)."
  echo "            The app launches normally; Developer ID + notarisation would"
  echo "            be needed to hand it to someone else."
fi

echo "==> done: $APP"
echo "    Launch: open \"$APP\"    (or double-click in Finder)"
echo "    First launch may ask for Input Monitoring for \"$APP_NAME\"."
echo "    Saves, settings and the remembered disc live inside the bundle."
#!/usr/bin/env bash
# Regenerates every launcher/store icon from the master logo.
#
#   ./tool/generate_app_icons.sh
#
# Source: assets/images/logo.png            (original logo artwork, transparent PNG)
# Master: assets/icon/logo_master_1024.png  (square 1024x1024; every output
#         below is derived from this single file)
#
# Outputs:
#   ios/Runner/Assets.xcassets/AppIcon.appiconset/*    (all iPhone/iPad sizes)
#   android/app/src/main/res/mipmap-*/ic_launcher.png  (48/72/96/144/192)
#   assets/store/appstore_icon_1024.png                (App Store Connect)
#   assets/store/playstore_icon_512.png                (Play Console)
#
# Run from the project root on macOS (uses the built-in sips tool).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/assets/images/logo.png"
MASTER="$ROOT/assets/icon/logo_master_1024.png"
IOS_DIR="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES="$ROOT/android/app/src/main/res"
STORE_DIR="$ROOT/assets/store"

command -v sips >/dev/null || { echo "error: sips not found (macOS only)" >&2; exit 1; }
[ -f "$SOURCE" ] || { echo "error: source logo missing: $SOURCE" >&2; exit 1; }

# 1. Master: normalize to PNG, scale to 1024 high, center-crop to square.
#    If the source is narrower than tall (e.g. 866x1024), crop to its own
#    width first, then upscale back to a full 1024x1024 square.
mkdir -p "$ROOT/assets/icon" "$STORE_DIR"
sips -s format png --resampleHeight 1024 "$SOURCE" --out "$MASTER" >/dev/null
W=$(sips -g pixelWidth "$MASTER" | awk '/pixelWidth/{print $2}')
if [ "$W" -lt 1024 ]; then
  sips -c "$W" "$W" "$MASTER" --out "$MASTER" >/dev/null
  sips -z 1024 1024 "$MASTER" --out "$MASTER" >/dev/null
else
  sips -c 1024 1024 "$MASTER" --out "$MASTER" >/dev/null
fi

# 2. iOS icon set. gen <pixels> <filename>
gen_ios() { sips -s format png -z "$1" "$1" "$MASTER" --out "$IOS_DIR/$2" >/dev/null; }
gen_ios 20  Icon-App-20x20@1x.png
gen_ios 40  Icon-App-20x20@2x.png
gen_ios 60  Icon-App-20x20@3x.png
gen_ios 29  Icon-App-29x29@1x.png
gen_ios 58  Icon-App-29x29@2x.png
gen_ios 87  Icon-App-29x29@3x.png
gen_ios 40  Icon-App-40x40@1x.png
gen_ios 80  Icon-App-40x40@2x.png
gen_ios 120 Icon-App-40x40@3x.png
gen_ios 120 Icon-App-60x60@2x.png
gen_ios 180 Icon-App-60x60@3x.png
gen_ios 76  Icon-App-76x76@1x.png
gen_ios 152 Icon-App-76x76@2x.png
gen_ios 167 Icon-App-83.5x83.5@2x.png
cp "$MASTER" "$IOS_DIR/Icon-App-1024x1024@1x.png"

# 3. Android launcher icons. gen_android <pixels> <dpi-dir>
gen_android() {
  sips -s format png -z "$1" "$1" "$MASTER" \
    --out "$ANDROID_RES/mipmap-$2/ic_launcher.png" >/dev/null
}
gen_android 48  mdpi
gen_android 72  hdpi
gen_android 96  xhdpi
gen_android 144 xxhdpi
gen_android 192 xxxhdpi

# 4. Store listing assets.
cp "$MASTER" "$STORE_DIR/appstore_icon_1024.png"
sips -s format png -z 512 512 "$MASTER" --out "$STORE_DIR/playstore_icon_512.png" >/dev/null

echo "✓ All icons regenerated from assets/images/logo.png"

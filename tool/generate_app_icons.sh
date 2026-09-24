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
WEB_DIR="$ROOT/web"

mkdir -p "$ROOT/assets/icon" "$STORE_DIR" "$IOS_DIR" "$WEB_DIR/icons"

# 1. Master generator using Python PIL:
#    Crops the 3D logo emblem tightly to its visible bounds,
#    scales it to ~660px (~64.5% of 1024) to match standard iOS/Android
#    app icon optical weight (Google, Upwork, Drive), and centers it on
#    an opaque crisp white 1024x1024 canvas.
python3 - <<EOF
from PIL import Image
import os

source_path = "$SOURCE"
master_path = "$MASTER"

img = Image.open(source_path).convert('RGBA')
w, h = img.size

min_x, min_y, max_x, max_y = w, h, 0, 0
for y in range(h):
    for x in range(w):
        r, g, b, a = img.getpixel((x, y))
        if a > 0:
            if x < min_x: min_x = x
            if x > max_x: max_x = x
            if y < min_y: min_y = y
            if y > max_y: max_y = y

cropped = img.crop((min_x, min_y, max_x + 1, max_y + 1))
cw, ch = cropped.size

# Target emblem size: 660px (~64.5% of 1024)
target_size = 660
scale = target_size / max(cw, ch)
new_w = int(cw * scale)
new_h = int(ch * scale)

resized = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

canvas = Image.new('RGBA', (1024, 1024), (255, 255, 255, 255))
offset_x = (1024 - new_w) // 2
offset_y = (1024 - new_h) // 2

canvas.paste(resized, (offset_x, offset_y), resized)
canvas.save(master_path, 'PNG')
print(f"✓ Master icon generated: {master_path} (emblem {new_w}x{new_h}, centered)")
EOF

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

# 5. Web icons.
sips -s format png -z 192 192 "$MASTER" --out "$WEB_DIR/icons/Icon-192.png" >/dev/null
sips -s format png -z 512 512 "$MASTER" --out "$WEB_DIR/icons/Icon-512.png" >/dev/null
sips -s format png -z 192 192 "$MASTER" --out "$WEB_DIR/icons/Icon-maskable-192.png" >/dev/null
sips -s format png -z 512 512 "$MASTER" --out "$WEB_DIR/icons/Icon-maskable-512.png" >/dev/null
sips -s format png -z 64 64 "$MASTER" --out "$WEB_DIR/favicon.png" >/dev/null

echo "✓ All icons regenerated with increased zoom from assets/images/logo.png"

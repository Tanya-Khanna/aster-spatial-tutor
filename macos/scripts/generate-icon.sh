#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SOURCE_ICON="$PROJECT_DIR/Resources/AsterIcon.svg"
OUTPUT_ICON="$PROJECT_DIR/Resources/Aster.icns"
WORK_DIR="$(mktemp -d /tmp/aster-icon.XXXXXX)"
ICONSET_DIR="$WORK_DIR/Aster.iconset"
MASTER_PNG="$WORK_DIR/Aster-1024.png"

trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$ICONSET_DIR"

sips -s format png "$SOURCE_ICON" --out "$MASTER_PNG" >/dev/null
sips -z 16 16 "$MASTER_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$MASTER_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$MASTER_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$MASTER_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$MASTER_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$MASTER_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$MASTER_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$MASTER_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$MASTER_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$MASTER_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICON"
echo "Generated $OUTPUT_ICON"

#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
ROOT_DIR="${PROJECT_DIR:h}"
BUILD_DIR="${PROJECT_DIR}/.build/release"
APP_DIR="${PROJECT_DIR}/dist/Aster.app"

cd "$PROJECT_DIR"
zsh scripts/generate-icon.sh
swift build -c release

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/Aster" "$APP_DIR/Contents/MacOS/Aster"
cp "$PROJECT_DIR/Resources/Aster.icns" "$APP_DIR/Contents/Resources/Aster.icns"

plutil -create xml1 "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleName -string "Aster✱" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleDisplayName -string "Aster✱" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string "com.aster.spatial-tutor" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleExecutable -string "Aster" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleIconFile -string "Aster" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string "0.3.3" "$APP_DIR/Contents/Info.plist"
plutil -insert CFBundleVersion -string "8" "$APP_DIR/Contents/Info.plist"
plutil -insert LSMinimumSystemVersion -string "13.0" "$APP_DIR/Contents/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$APP_DIR/Contents/Info.plist"
plutil -insert NSScreenCaptureUsageDescription -string "Aster✱ sees the screen you explicitly select so it can teach with on-target annotations." "$APP_DIR/Contents/Info.plist"
plutil -insert NSMicrophoneUsageDescription -string "Aster✱ uses your microphone when you ask a question by voice." "$APP_DIR/Contents/Info.plist"
plutil -insert NSSpeechRecognitionUsageDescription -string "Aster✱ transcribes your spoken learning questions on your Mac." "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ROOT_DIR/public/Aster-macOS.zip"

echo "Packaged $APP_DIR"
echo "Download archive: $ROOT_DIR/public/Aster-macOS.zip"

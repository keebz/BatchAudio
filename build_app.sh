#!/bin/bash
# Builds "Batch Audio Converter.app" in this folder.
set -e
cd "$(dirname "$0")"

if [ "${UNIVERSAL:-0}" = "1" ]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN=.build/apple/Products/Release/BatchAudio
else
  swift build -c release
  BIN=.build/release/BatchAudio
fi
APP="Batch Audio Converter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BatchAudio"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Bundle ffmpeg if one has been built (scripts/build_ffmpeg.sh) or supplied via FFMPEG_BIN.
FF="${FFMPEG_BIN:-build/ffmpeg/out/ffmpeg}"
if [ -x "$FF" ]; then
  cp "$FF" "$APP/Contents/Resources/ffmpeg"
  LIC="$(dirname "$FF")"
  if [ -d "$LIC/licenses" ]; then
    mkdir -p "$APP/Contents/Resources/Licenses"
    cp "$LIC"/licenses/* "$APP/Contents/Resources/Licenses/"
    [ -f "$LIC/BUILD-INFO.txt" ] && cp "$LIC/BUILD-INFO.txt" "$APP/Contents/Resources/Licenses/"
  fi
  echo "Bundled ffmpeg from $FF"
else
  echo "No bundled ffmpeg (run scripts/build_ffmpeg.sh first); app will use a system ffmpeg."
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Batch Audio Converter</string>
  <key>CFBundleDisplayName</key><string>Batch Audio Converter</string>
  <key>CFBundleIdentifier</key><string>com.local.batchaudioconverter</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>BatchAudio</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "Built: $(pwd)/$APP"

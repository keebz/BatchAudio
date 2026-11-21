#!/bin/bash
# Usage: bash scripts/make_release.sh 1.0
# Run on a Mac. Builds a universal (Apple Silicon + Intel) app and packages it
# into dist/ with a SHA-256 checksum, ready to upload to a GitHub Release.
set -e
cd "$(dirname "$0")/.."
VERSION="${1:?usage: make_release.sh <version, e.g. 1.0>}"

[ -x build/ffmpeg/out/ffmpeg ] || bash scripts/build_ffmpeg.sh
UNIVERSAL=1 bash build_app.sh
APP="Batch Audio Converter.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

mkdir -p dist
ZIP="dist/BatchAudioConverter-$VERSION-macOS.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
git archive --format=zip --prefix="BatchAudio-$VERSION/" -o "dist/BatchAudio-$VERSION-source.zip" HEAD 2>/dev/null || true
echo; echo "Upload these to the release:"; ls -1 dist

#!/bin/bash
# Builds a small, universal (arm64 + x86_64), statically linked, LGPL-licensed
# ffmpeg for bundling inside Batch Audio Converter.app.
#
#   bash scripts/build_ffmpeg.sh
#
# Output:  build/ffmpeg/out/ffmpeg            (universal, ad-hoc signed)
#          build/ffmpeg/out/licenses/         (license texts to ship with it)
#          build/ffmpeg/out/BUILD-INFO.txt    (versions, source URLs, configure line)
#
# Needs macOS with Xcode command-line tools, plus:  brew install nasm pkgconf
#
# Licensing: this is NOT built with --enable-gpl / --enable-nonfree, so the binary
# is LGPL v2.1+. Included encoders: LAME (LGPL), libvorbis, libogg, libopus (BSD).
set -euo pipefail
cd "$(dirname "$0")/.."

FFMPEG_VER=7.1.1
LAME_VER=3.100
OGG_VER=1.3.5
VORBIS_VER=1.3.7
OPUS_VER=1.5.2
MIN_MACOS=13.0

# name|url|sha256
SOURCES="
ffmpeg-$FFMPEG_VER.tar.xz|https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VER.tar.xz|733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1
lame-$LAME_VER.tar.gz|https://downloads.sourceforge.net/project/lame/lame/$LAME_VER/lame-$LAME_VER.tar.gz|ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e
libogg-$OGG_VER.tar.xz|https://downloads.xiph.org/releases/ogg/libogg-$OGG_VER.tar.xz|c4d91be36fc8e54deae7575241e03f4211eb102afb3fc0775fbbc1b740016705
libvorbis-$VORBIS_VER.tar.xz|https://downloads.xiph.org/releases/vorbis/libvorbis-$VORBIS_VER.tar.xz|b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b
opus-$OPUS_VER.tar.gz|https://downloads.xiph.org/releases/opus/opus-$OPUS_VER.tar.gz|65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1
"

[ "$(uname -s)" = "Darwin" ] || { echo "This script must run on macOS." >&2; exit 1; }
for t in clang make nasm pkg-config lipo codesign shasum curl; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t  (brew install nasm pkgconf)" >&2; exit 1; }
done

ROOT="$PWD/build/ffmpeg"
SRC="$ROOT/src"; OUT="$ROOT/out"
JOBS="$(sysctl -n hw.ncpu)"
HOST_ARCH="$(uname -m)"   # arm64 or x86_64
mkdir -p "$SRC" "$OUT/licenses"

# ---- fetch + verify + unpack ------------------------------------------------
echo "$SOURCES" | while IFS='|' read -r name url sha; do
  [ -n "$name" ] || continue
  if [ ! -f "$SRC/$name" ]; then echo "Downloading $name"; curl -fsSL -L -o "$SRC/$name" "$url"; fi
  echo "$sha  $SRC/$name" | shasum -a 256 -c - >/dev/null || { echo "Checksum mismatch: $name" >&2; exit 1; }
done

build_arch() {
  local ARCH="$1"                         # arm64 | x86_64
  local TRIPLE; [ "$ARCH" = arm64 ] && TRIPLE=aarch64-apple-darwin || TRIPLE=x86_64-apple-darwin
  local BUILD_TRIPLE; [ "$HOST_ARCH" = arm64 ] && BUILD_TRIPLE=aarch64-apple-darwin || BUILD_TRIPLE=x86_64-apple-darwin
  local W="$ROOT/work-$ARCH"; local P="$W/prefix"
  rm -rf "$W"; mkdir -p "$W" "$P"

  export CC="clang -arch $ARCH -mmacosx-version-min=$MIN_MACOS"
  export CFLAGS="-O2 -I$P/include"
  export LDFLAGS="-L$P/lib"
  export PKG_CONFIG_PATH="$P/lib/pkgconfig"
  export PKG_CONFIG_LIBDIR="$P/lib/pkgconfig"

  untar() { tar -xf "$SRC/$1" -C "$W"; }
  common="--host=$TRIPLE --build=$BUILD_TRIPLE --prefix=$P --disable-shared --enable-static"

  echo "=== [$ARCH] libogg"
  untar "libogg-$OGG_VER.tar.xz"; ( cd "$W/libogg-$OGG_VER" && ./configure $common >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null )

  echo "=== [$ARCH] libvorbis"
  untar "libvorbis-$VORBIS_VER.tar.xz"; ( cd "$W/libvorbis-$VORBIS_VER" && sed -i.bak 's/-force_cpusubtype_ALL//g' configure && ./configure $common --disable-examples --disable-docs --disable-oggtest >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null )

  echo "=== [$ARCH] opus"
  untar "opus-$OPUS_VER.tar.gz"; ( cd "$W/opus-$OPUS_VER" && ./configure $common --disable-doc --disable-extra-programs >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null )

  echo "=== [$ARCH] lame"
  untar "lame-$LAME_VER.tar.gz"; ( cd "$W/lame-$LAME_VER" && ./configure $common --disable-frontend --disable-decoder --disable-gtktest >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null )

  echo "=== [$ARCH] ffmpeg"
  untar "ffmpeg-$FFMPEG_VER.tar.xz"
  local cross=""; [ "$ARCH" != "$HOST_ARCH" ] && cross="--enable-cross-compile"
  ( cd "$W/ffmpeg-$FFMPEG_VER" && ./configure \
      --prefix="$P" --arch="$ARCH" --target-os=darwin $cross \
      --cc="clang -arch $ARCH" \
      --disable-autodetect --disable-shared --enable-static \
      --disable-doc --disable-debug --disable-network \
      --disable-ffplay --disable-ffprobe --enable-ffmpeg \
      --enable-zlib --enable-iconv \
      --enable-libmp3lame --enable-libvorbis --enable-libopus \
      --disable-encoders \
      --enable-encoder=aac,alac,flac,libmp3lame,libvorbis,libopus,pcm_s16le,pcm_s24le,pcm_s32le,pcm_s16be,pcm_s24be,pcm_s32be \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$P/include -mmacosx-version-min=$MIN_MACOS" \
      --extra-ldflags="-L$P/lib -mmacosx-version-min=$MIN_MACOS" \
      > "$W/configure.log" 2>&1 || { tail -40 "$W/configure.log"; exit 1; }
    make -j"$JOBS" ffmpeg >/dev/null
    cp ffmpeg "$W/ffmpeg-bin"; strip -x "$W/ffmpeg-bin" )
}

build_arch arm64
build_arch x86_64

echo "=== lipo + sign"
lipo -create "$ROOT/work-arm64/ffmpeg-bin" "$ROOT/work-x86_64/ffmpeg-bin" -output "$OUT/ffmpeg"
chmod +x "$OUT/ffmpeg"
codesign --force --sign - "$OUT/ffmpeg"

# ---- licenses + build info --------------------------------------------------
W="$ROOT/work-arm64"
cp "$W/ffmpeg-$FFMPEG_VER/COPYING.LGPLv2.1" "$OUT/licenses/FFmpeg-LGPL-2.1.txt"
cp "$W/ffmpeg-$FFMPEG_VER/LICENSE.md"       "$OUT/licenses/FFmpeg-LICENSE.md"
cp "$W/lame-$LAME_VER/COPYING"              "$OUT/licenses/LAME-LGPL-2.txt"
cp "$W/libogg-$OGG_VER/COPYING"             "$OUT/licenses/libogg-BSD.txt"
cp "$W/libvorbis-$VORBIS_VER/COPYING"       "$OUT/licenses/libvorbis-BSD.txt"
cp "$W/opus-$OPUS_VER/COPYING"              "$OUT/licenses/libopus-BSD.txt"

{
  echo "Bundled ffmpeg for Batch Audio Converter"
  echo "Built with: scripts/build_ffmpeg.sh in this repository."
  echo
  echo "$SOURCES" | awk -F'|' 'NF>=2 {print $1 "  " $2}'
  echo
  echo "ffmpeg is licensed under the LGPL v2.1 or later (no GPL or non-free parts)."
  echo "You can rebuild it from the sources above with the script, and replace the"
  echo "bundled copy (Contents/Resources/ffmpeg) with your own build."
  echo
  "$OUT/ffmpeg" -hide_banner -version 2>/dev/null | sed -n '1p;/configuration/p' || true
} > "$OUT/BUILD-INFO.txt"

# ---- self-test (native arch only) ------------------------------------------
echo "=== self-test"
if "$OUT/ffmpeg" -version | grep -q -e '--enable-gpl' -e '--enable-nonfree'; then
  echo "ERROR: build is GPL/non-free" >&2; exit 1
fi
T="$ROOT/selftest"; rm -rf "$T"; mkdir -p "$T"
"$OUT/ffmpeg" -hide_banner -loglevel error -f lavfi -i "sine=frequency=440:duration=1" "$T/in.wav"
for spec in "mp3:-c:a libmp3lame -b:a 192k" "m4a:-c:a aac -b:a 192k" "m4a:-c:a alac" "flac:-c:a flac" \
            "ogg:-c:a libvorbis -b:a 192k" "opus:-c:a libopus -b:a 128k" "wav:-c:a pcm_s24le" "aiff:-c:a pcm_s24be"; do
  ext="${spec%%:*}"; args="${spec#*:}"
  "$OUT/ffmpeg" -hide_banner -loglevel error -nostdin -y -i "$T/in.wav" $args "$T/out-$RANDOM.$ext"
  echo "  ok: $ext ($args)"
done
lipo -info "$OUT/ffmpeg"
ls -lh "$OUT/ffmpeg"
echo "Done: $OUT/ffmpeg"

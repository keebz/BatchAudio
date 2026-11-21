## Batch Audio Converter 1.0

Simple macOS app for batch-converting audio files with ffmpeg.

**Features**
- Drag in files or whole folders (subfolders included)
- MP3, AAC, ALAC, FLAC, WAV, AIFF, Ogg Vorbis, Opus
- Bit rate, bit depth, sample rate, mono/stereo
- Keep originals, or replace them (originals go to the Trash)
- Keep or clear metadata; cover art preserved where supported

**Requirements:** macOS 13 or newer, and ffmpeg (`brew install ffmpeg`). ffmpeg is not included.

**Install:** unzip, drag **Batch Audio Converter.app** to Applications. The app is ad-hoc signed, not notarized, so on first launch right-click it, choose **Open**, then confirm. If macOS still refuses, run `xattr -dr com.apple.quarantine "/Applications/Batch Audio Converter.app"`.

See the [User Manual](docs/MANUAL.md).

**Disclaimer:** provided "as is", without warranty of any kind. Back up your files before converting. MIT licensed.

Verify the download: `shasum -a 256 -c BatchAudioConverter-1.0-macOS.zip.sha256`

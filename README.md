# Batch Audio Converter

> [!CAUTION]
> **DISCLAIMER: NO WARRANTY.** This software is provided **"as is", without warranty of any kind**. The authors are not liable for any loss or damage, including lost or overwritten files. Back up your audio before converting, especially when using "Replace".

Simple macOS (13+) app for batch-converting audio files. Drag in files or folders, pick format, bit rate / bit depth, sample rate and channels (mono/stereo), choose whether to keep or replace the originals and whether to keep or clear metadata. Uses ffmpeg under the hood (bundled).

![Main window](docs/images/files.png)

## Requirements
- macOS 13 (Ventura) or newer, Apple Silicon or Intel

ffmpeg is **bundled inside the app**, so there is nothing else to install.

## Installation

### Download the app (easiest)
1. Download the latest `BatchAudioConverter-<version>-macOS.zip` from the [Releases](../../releases) page.
2. Unzip it and drag **Batch Audio Converter.app** into your **Applications** folder.
3. The first time you open it, **right-click the app, choose Open, then confirm.** The app is not notarized by Apple, so macOS warns about it the first time. If macOS still refuses, run:
   ```
   xattr -dr com.apple.quarantine "/Applications/Batch Audio Converter.app"
   ```

### Or build from source
You need the Swift toolchain (`xcode-select --install`).
```
brew install nasm pkgconf          # tools for building the bundled ffmpeg
git clone https://github.com/keebz/BatchAudio.git
cd BatchAudio
bash scripts/build_ffmpeg.sh       # builds a universal LGPL ffmpeg (several minutes, once)
bash build_app.sh
```
This produces `Batch Audio Converter.app` in the project folder; drag it to Applications. An app you build yourself opens normally.

Want a quicker build? Skip `build_ffmpeg.sh`; the app then falls back to a system ffmpeg (`brew install ffmpeg`) and shows a yellow banner if none is found.

## Documentation
See the **[User Manual](docs/MANUAL.md)** for a walkthrough with screenshots.

## License
[MIT](LICENSE). The bundled ffmpeg is a separate program under the LGPL v2.1+ (with LAME, libvorbis, libogg and libopus); see [THIRD_PARTY.md](THIRD_PARTY.md).

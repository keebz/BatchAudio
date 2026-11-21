# Batch Audio Converter

Simple macOS (13+) app for batch-converting audio files. Drag in files or folders, pick format, bit rate / bit depth, sample rate and channels (mono/stereo), choose whether to keep or replace the originals and whether to keep or clear metadata. Uses ffmpeg under the hood.

![Main window](docs/images/files.png)

## Requirements
- macOS 13 (Ventura) or newer
- [ffmpeg](https://ffmpeg.org) (does the actual conversion; not included)

## Installation

### 1. Install ffmpeg
Install [Homebrew](https://brew.sh) if you don't have it, then in Terminal:
```
brew install ffmpeg
```

### 2a. Download the app (easiest)
1. Download the latest `BatchAudioConverter-<version>-macOS.zip` from the [Releases](../../releases) page.
2. Unzip it and drag **Batch Audio Converter.app** into your **Applications** folder.
3. The first time you open it, **right-click the app, choose Open, then confirm.** The app is not notarized by Apple, so macOS warns about it the first time. If macOS still refuses, run:
   ```
   xattr -dr com.apple.quarantine "/Applications/Batch Audio Converter.app"
   ```

### 2b. Or build from source
You need the Swift toolchain (`xcode-select --install`).
```
git clone https://github.com/keebz/BatchAudio.git
cd BatchAudio
bash build_app.sh
```
This produces `Batch Audio Converter.app` in the project folder; drag it to Applications. An app you build yourself opens normally.

If the app shows a yellow "ffmpeg not found" banner, install ffmpeg as in step 1 and click **Check Again**.

## Documentation
See the **[User Manual](docs/MANUAL.md)** for a walkthrough with screenshots.

## Disclaimer
This software is provided **"as is", without warranty of any kind**. The authors are not liable for any loss or damage, including lost or overwritten files. Back up your audio before converting, especially when using "Replace".

## License
[MIT](LICENSE). ffmpeg is a separate program with its own license and is not included.

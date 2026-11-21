# Third-party software

Release builds of Batch Audio Converter bundle a copy of **ffmpeg** at
`Batch Audio Converter.app/Contents/Resources/ffmpeg`. It is a separate program that the
app launches to do the conversion. It is **not** covered by this project's MIT License.

| Component | Version | License |
|---|---|---|
| FFmpeg | 7.1.1 | LGPL v2.1 or later (built without `--enable-gpl` / `--enable-nonfree`) |
| LAME (MP3 encoder) | 3.100 | LGPL v2 |
| libvorbis | 1.3.7 | BSD-3-Clause |
| libogg | 1.3.5 | BSD-3-Clause |
| Opus | 1.5.2 | BSD-3-Clause |

Full license texts ship inside the app in `Contents/Resources/Licenses/`.

## Source code and rebuilding

The exact source tarballs (with SHA-256 checksums) and the build recipe are in
[`scripts/build_ffmpeg.sh`](scripts/build_ffmpeg.sh). To rebuild:

```
brew install nasm pkgconf
bash scripts/build_ffmpeg.sh
bash build_app.sh
```

## Replacing the bundled ffmpeg

Because ffmpeg is a standalone executable, you can swap in your own build: replace
`Contents/Resources/ffmpeg` inside the app, or build the app with
`FFMPEG_BIN=/path/to/ffmpeg bash build_app.sh`.

This project is not affiliated with or endorsed by the FFmpeg project.

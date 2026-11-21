import Foundation

enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case mp3 = "MP3"
    case aac = "AAC (.m4a)"
    case alac = "ALAC (.m4a, lossless)"
    case flac = "FLAC"
    case wav = "WAV"
    case aiff = "AIFF"
    case ogg = "Ogg Vorbis"
    case opus = "Opus"

    var id: String { rawValue }

    var ext: String {
        switch self {
        case .mp3: return "mp3"
        case .aac, .alac: return "m4a"
        case .flac: return "flac"
        case .wav: return "wav"
        case .aiff: return "aiff"
        case .ogg: return "ogg"
        case .opus: return "opus"
        }
    }

    var isLossy: Bool { self == .mp3 || self == .aac || self == .ogg || self == .opus }
    var supportsDepth: Bool { self == .flac || self == .alac || self == .wav || self == .aiff }
    var supportsArt: Bool { self == .mp3 || self == .aac || self == .alac || self == .flac }

    var depths: [Int] {
        switch self {
        case .wav, .aiff: return [16, 24, 32]
        default: return [16, 24]
        }
    }

    var bitRates: [Int] {
        switch self {
        case .mp3, .aac, .ogg: return [64, 96, 128, 160, 192, 256, 320]
        case .opus: return [32, 48, 64, 96, 128, 160, 192, 256]
        default: return []
        }
    }

    var sampleRates: [Int] {
        switch self {
        case .mp3: return [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
        case .opus: return [8000, 12000, 16000, 24000, 48000]
        case .aac, .ogg: return [8000, 11025, 16000, 22050, 32000, 44100, 48000, 88200, 96000]
        default: return [8000, 11025, 16000, 22050, 32000, 44100, 48000, 88200, 96000, 176400, 192000]
        }
    }
}

struct Settings: Sendable {
    var format: OutputFormat
    var bitRate: Int          // kbps, lossy formats only
    var bitDepth: Int         // lossless/PCM formats only
    var sampleRate: Int       // 0 = keep original
    var channels: Int         // 0 = keep, 1 = mono, 2 = stereo
    var replaceOriginal: Bool
    var clearMetadata: Bool
    var outputFolder: URL?    // nil = same folder as original
}

struct ConvError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum Converter {
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aif", "aiff", "aifc", "flac", "ogg", "oga", "opus",
        "wma", "caf", "ac3", "eac3", "amr", "mka", "mp2", "wv", "ape", "dsf", "au", "webm", "mp4", "mov"
    ]
    static let videoExtensions: Set<String> = ["mp4", "mov", "mkv", "avi", "webm", "m4v"]

    static func findFFmpeg() -> String? {
        var candidates: [String] = []
        if let r = Bundle.main.resourcePath { candidates.append(r + "/ffmpeg") }
        candidates += ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/opt/local/bin/ffmpeg"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: ffmpeg arguments

    static func args(input: URL, output: URL, s: Settings, art: Bool) -> [String] {
        var a = ["-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                 "-i", input.path, "-map", "0:a:0"]

        if art {
            a += ["-map", "0:v:0?", "-c:v", "copy", "-disposition:v:0", "attached_pic"]
        }

        switch s.format {
        case .mp3:  a += ["-c:a", "libmp3lame", "-b:a", "\(s.bitRate)k"]
        case .aac:  a += ["-c:a", "aac", "-b:a", "\(s.bitRate)k"]
        case .ogg:  a += ["-c:a", "libvorbis", "-b:a", "\(s.bitRate)k"]
        case .opus: a += ["-c:a", "libopus", "-b:a", "\(s.bitRate)k"]
        case .flac:
            a += ["-c:a", "flac"]
            a += s.bitDepth == 16 ? ["-sample_fmt", "s16"] : ["-sample_fmt", "s32", "-bits_per_raw_sample", "24"]
        case .alac:
            a += ["-c:a", "alac"]
            a += s.bitDepth == 16 ? ["-sample_fmt", "s16p"] : ["-sample_fmt", "s32p", "-bits_per_raw_sample", "24"]
        case .wav:  a += ["-c:a", "pcm_s\(s.bitDepth)le"]
        case .aiff: a += ["-c:a", "pcm_s\(s.bitDepth)be"]
        }

        if s.sampleRate > 0 { a += ["-ar", "\(s.sampleRate)"] }
        if s.channels > 0 { a += ["-ac", "\(s.channels)"] }

        if s.clearMetadata {
            a += ["-map_metadata", "-1", "-map_chapters", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact"]
        } else {
            a += ["-map_metadata", "0"]
        }
        if s.format == .mp3 { a += ["-id3v2_version", "3"] }

        a.append(output.path)
        return a
    }

    static func run(_ ffmpeg: String, _ args: [String]) -> (status: Int32, log: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = args
        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    static func unique(_ url: URL) -> URL {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 1
        var candidate = url
        repeat {
            let suffix = n == 1 ? " (converted)" : " (converted \(n))"
            candidate = dir.appendingPathComponent(base + suffix).appendingPathExtension(ext)
            n += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    // MARK: convert one file

    static func convert(input: URL, ffmpeg: String, s: Settings) throws -> URL {
        let fm = FileManager.default
        let dir = s.replaceOriginal
            ? input.deletingLastPathComponent()
            : (s.outputFolder ?? input.deletingLastPathComponent())
        let base = input.deletingPathExtension().lastPathComponent
        let ext = s.format.ext
        let temp = dir.appendingPathComponent(".\(base).tmp-\(UUID().uuidString.prefix(8))")
            .appendingPathExtension(ext)

        do {
            let wantArt = !s.clearMetadata && s.format.supportsArt
                && !videoExtensions.contains(input.pathExtension.lowercased())

            var result = run(ffmpeg, args(input: input, output: temp, s: s, art: wantArt))
            if result.status != 0 && wantArt {
                // Cover art can trip up some sources; retry without it.
                try? fm.removeItem(at: temp)
                result = run(ffmpeg, args(input: input, output: temp, s: s, art: false))
            }

            let size = (try? fm.attributesOfItem(atPath: temp.path)[.size] as? NSNumber)??.intValue ?? 0
            guard result.status == 0, size > 0 else {
                let line = result.log.split(separator: "\n").last.map(String.init) ?? "ffmpeg failed"
                throw ConvError(message: line)
            }

            var final = dir.appendingPathComponent(base).appendingPathExtension(ext)
            if s.replaceOriginal {
                // Original goes to the Trash only after the new file is safely written.
                try fm.trashItem(at: input, resultingItemURL: nil)
            }
            if fm.fileExists(atPath: final.path) { final = unique(final) }
            try fm.moveItem(at: temp, to: final)
            return final
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }
}

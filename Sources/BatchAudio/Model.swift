import SwiftUI
import AppKit

struct Item: Identifiable {
    enum Status { case pending, running, done(String), failed(String) }
    let id = UUID()
    let url: URL
    var status: Status = .pending
}

@MainActor
final class Model: ObservableObject {
    @Published var items: [Item] = []
    @Published var selection = Set<UUID>()
    @Published var isRunning = false
    @Published var ffmpegPath: String? = Converter.findFFmpeg()

    @Published var format: OutputFormat = .mp3 { didSet { normalize() } }
    @Published var bitRate = 192
    @Published var bitDepth = 24
    @Published var sampleRate = 0
    @Published var channels = 0
    @Published var replaceOriginal = false
    @Published var clearMetadata = false
    @Published var outputFolder: URL?

    private var cancelled = false

    var settings: Settings {
        Settings(format: format, bitRate: bitRate, bitDepth: bitDepth, sampleRate: sampleRate,
                 channels: channels, replaceOriginal: replaceOriginal,
                 clearMetadata: clearMetadata, outputFolder: replaceOriginal ? nil : outputFolder)
    }

    var pendingCount: Int {
        items.filter { if case .pending = $0.status { return true }; if case .failed = $0.status { return true }; return false }.count
    }
    var finishedCount: Int {
        items.filter { if case .done = $0.status { return true }; if case .failed = $0.status { return true }; return false }.count
    }

    private func normalize() {
        let rates = format.bitRates
        if !rates.isEmpty && !rates.contains(bitRate) {
            bitRate = rates.min(by: { abs($0 - bitRate) < abs($1 - bitRate) }) ?? 128
        }
        if sampleRate != 0 && !format.sampleRates.contains(sampleRate) { sampleRate = 0 }
        if format.supportsDepth && !format.depths.contains(bitDepth) { bitDepth = 24 }
    }

    // MARK: files

    func add(_ urls: [URL]) {
        var seen = Set(items.map(\.url))
        let fm = FileManager.default
        for u in urls {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue {
                if let en = fm.enumerator(at: u, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for case let f as URL in en where Converter.audioExtensions.contains(f.pathExtension.lowercased()) {
                        if seen.insert(f).inserted { items.append(Item(url: f)) }
                    }
                }
            } else if seen.insert(u).inserted {
                items.append(Item(url: u))
            }
        }
    }

    func pickFiles() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseFiles = true
        p.canChooseDirectories = true
        if p.runModal() == .OK { add(p.urls) }
    }

    func pickFolder() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.canCreateDirectories = true
        p.prompt = "Choose"
        if p.runModal() == .OK { outputFolder = p.url }
    }

    func removeSelected() {
        items.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }

    func clearAll() { if !isRunning { items.removeAll(); selection.removeAll() } }

    func clearCompleted() {
        items.removeAll { if case .done = $0.status { return true }; return false }
    }

    func recheckFFmpeg() { ffmpegPath = Converter.findFFmpeg() }

    // MARK: run

    func stop() { cancelled = true }

    func start() {
        guard let ff = ffmpegPath, !isRunning else { return }
        let s = settings
        isRunning = true
        cancelled = false
        let ids = items.filter {
            if case .pending = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }.map(\.id)

        Task {
            for id in ids {
                if cancelled { break }
                guard let i = items.firstIndex(where: { $0.id == id }) else { continue }
                items[i].status = .running
                let url = items[i].url
                do {
                    let out = try await Task.detached { try Converter.convert(input: url, ffmpeg: ff, s: s) }.value
                    if let j = items.firstIndex(where: { $0.id == id }) { items[j].status = .done(out.lastPathComponent) }
                } catch {
                    if let j = items.firstIndex(where: { $0.id == id }) { items[j].status = .failed(error.localizedDescription) }
                }
            }
            // Anything still marked running (shouldn't happen) goes back to pending.
            for k in items.indices { if case .running = items[k].status { items[k].status = .pending } }
            isRunning = false
        }
    }
}

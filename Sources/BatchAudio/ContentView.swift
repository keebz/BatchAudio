import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = Model()
    @State private var dropTargeted = false
    @State private var confirmReplace = false

    var body: some View {
        VStack(spacing: 0) {
            if model.ffmpegPath == nil { ffmpegBanner }
            fileList
            Divider()
            settingsForm
            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 720)
        .alert("Replace original files?", isPresented: $confirmReplace) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) { model.start() }
        } message: {
            Text("Each original is moved to the Trash after its converted file is written successfully.")
        }
    }

    // MARK: pieces

    private var ffmpegBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("ffmpeg not found. Install it in Terminal with:  brew install ffmpeg")
            Spacer()
            Button("Check Again") { model.recheckFFmpeg() }
        }
        .padding(10)
        .background(.yellow.opacity(0.15))
    }

    private var fileList: some View {
        ZStack {
            if model.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.badge.plus").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Drop audio files or folders here").font(.headline)
                    Text("or click Add Files…").foregroundStyle(.secondary)
                }
            } else {
                List(model.items, selection: $model.selection) { item in
                    RowView(item: item)
                }
                .onDeleteCommand { model.removeSelected() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: dropTargeted ? 3 : 0)
                .padding(2)
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url { Task { @MainActor in model.add([url]) } }
                }
            }
            return true
        }
    }

    private var settingsForm: some View {
        Form {
            Picker("Format", selection: $model.format) {
                ForEach(OutputFormat.allCases) { Text($0.rawValue).tag($0) }
            }
            if model.format.isLossy {
                Picker("Bit rate", selection: $model.bitRate) {
                    ForEach(model.format.bitRates, id: \.self) { Text("\($0) kbps").tag($0) }
                }
            }
            if model.format.supportsDepth {
                Picker("Bit depth", selection: $model.bitDepth) {
                    ForEach(model.format.depths, id: \.self) { Text("\($0)-bit").tag($0) }
                }
            }
            Picker("Sample rate", selection: $model.sampleRate) {
                Text("Keep original").tag(0)
                ForEach(model.format.sampleRates, id: \.self) { Text("\($0) Hz").tag($0) }
            }
            Picker("Channels", selection: $model.channels) {
                Text("Keep original").tag(0)
                Text("Mono").tag(1)
                Text("Stereo").tag(2)
            }
            Picker("Original files", selection: $model.replaceOriginal) {
                Text("Leave in place (save new copies)").tag(false)
                Text("Replace (originals go to Trash)").tag(true)
            }
            Picker("Metadata", selection: $model.clearMetadata) {
                Text("Keep original metadata").tag(false)
                Text("Clear all metadata").tag(true)
            }
            if !model.replaceOriginal {
                HStack {
                    Text("Save copies to")
                    Spacer()
                    Text(model.outputFolder?.path ?? "Same folder as original")
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                    Button("Choose…") { model.pickFolder() }
                    if model.outputFolder != nil { Button("Reset") { model.outputFolder = nil } }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 320, maxHeight: 380)
        .disabled(model.isRunning)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Add Files…") { model.pickFiles() }.disabled(model.isRunning)
            Button("Remove Selected") { model.removeSelected() }
                .disabled(model.selection.isEmpty || model.isRunning)
            Button("Clear Completed") { model.clearCompleted() }.disabled(model.isRunning)
            Button("Clear All") { model.clearAll() }.disabled(model.items.isEmpty || model.isRunning)
            Spacer()
            if model.isRunning || model.finishedCount > 0 {
                ProgressView(value: Double(model.finishedCount), total: Double(max(model.items.count, 1)))
                    .frame(width: 120)
                Text("\(model.finishedCount) of \(model.items.count)").foregroundStyle(.secondary)
            }
            if model.isRunning {
                Button("Stop") { model.stop() }
            } else {
                Button("Convert \(model.pendingCount) File\(model.pendingCount == 1 ? "" : "s")") {
                    if model.replaceOriginal { confirmReplace = true } else { model.start() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.pendingCount == 0 || model.ffmpegPath == nil)
            }
        }
        .padding(12)
    }
}

struct RowView: View {
    let item: Item

    var body: some View {
        HStack {
            Image(systemName: "waveform").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).lineLimit(1)
                detail
            }
            Spacer()
            status
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var detail: some View {
        switch item.status {
        case .done(let name):
            Text("→ \(name)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).lineLimit(2)
        default:
            Text(item.url.deletingLastPathComponent().path)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
        }
    }

    @ViewBuilder private var status: some View {
        switch item.status {
        case .pending: Text("Waiting").foregroundStyle(.secondary)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}

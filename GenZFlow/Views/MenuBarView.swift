import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    var onStyleChanged: ((SlangStyle) -> Void)?
    var onRecordToggle: () -> Void
    var onQuit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                    .overlay(
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                            .opacity(appState.recordingState == .recording ? 0.5 : 0)
                            .scaleEffect(appState.recordingState == .recording ? 2.0 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appState.recordingState)
                    )
                Text(appState.recordingState.statusText).font(.system(size: 13)).lineLimit(2)
            }.padding(.horizontal, 12).padding(.top, 8)
            
            Divider()

            Button(action: onRecordToggle) {
                HStack(spacing: 8) {
                    Image(systemName: appState.recordingState == .recording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 14))
                    Text(appState.recordingState == .recording ? "Stop Recording" : "Start Recording")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .disabled(!appState.isWhisperReady || appState.recordingState.isProcessing && appState.recordingState != .recording)
            .opacity(!appState.isWhisperReady || appState.recordingState.isProcessing && appState.recordingState != .recording ? 0.4 : 1.0)

            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Translation style").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).padding(.horizontal, 12)
                ForEach(SlangStyle.allCases) { style in
                    Button(action: { appState.selectedStyle = style; onStyleChanged?(style) }) {
                        HStack(spacing: 8) {
                            Image(systemName: style.icon).font(.system(size: 12)).frame(width: 16)
                            Text(style.rawValue).font(.system(size: 13))
                            Spacer()
                            if appState.selectedStyle == style {
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundColor(.accentColor)
                            }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 3)
                }
            }
            
            Divider()
            
            HStack {
                Image(systemName: appState.isWhisperReady ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(appState.isWhisperReady ? .green : .orange).font(.system(size: 12))
                Text(appState.isWhisperReady ? "Whisper ready" : "Loading Whisper...").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Image(systemName: "bubble.left.fill").font(.system(size: 10)).foregroundColor(.purple)
                Text("\(appState.translationCount)").font(.system(size: 12)).foregroundColor(.secondary)
            }.padding(.horizontal, 12)
            
            if !appState.lastTranslation.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    if !appState.originalTranscript.isEmpty {
                        Text(appState.originalTranscript).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2).italic()
                    }
                    Text(appState.lastTranslation).font(.system(size: 12, weight: .medium)).lineLimit(3).textSelection(.enabled)
                }.padding(.horizontal, 12)
            }
            
            Divider()
            
            HStack {
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(appState.lastTranslation, forType: .string) }) {
                    HStack(spacing: 4) { Image(systemName: "doc.on.doc"); Text("Copy last") }.font(.system(size: 12))
                }.buttonStyle(.plain).disabled(appState.lastTranslation.isEmpty).opacity(appState.lastTranslation.isEmpty ? 0.4 : 1.0)
                Spacer()
                Button(action: onQuit) {
                    HStack(spacing: 4) { Image(systemName: "power"); Text("Quit") }.font(.system(size: 12))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.bottom, 8)
        }.frame(width: 280)
    }
    
    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return .green; case .recording: return .red
        case .transcribing, .translating: return .orange
        case .done: return .blue; case .error: return .red
        }
    }
}

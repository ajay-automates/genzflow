import SwiftUI
import AppKit

@main
struct GenZFlowApp: App {
    @StateObject private var appState = AppState()
    
    private let hotkeyService = HotkeyService()
    private let audioService = AudioService()
    private let transcriptionService = TranscriptionService()
    private let translationService = TranslationService()
    private let pasteService = PasteService()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState, onStyleChanged: { style in
                translationService.currentStyle = style
            }) {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarIcon)
                Text("GZ").font(.system(size: 10, weight: .bold))
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: appState.recordingState) { _, _ in }
    }
    
    private var menuBarIcon: String {
        switch appState.recordingState {
        case .recording: return "mic.fill"
        case .transcribing, .translating: return "brain.head.profile"
        case .error: return "exclamationmark.triangle"
        default: return "waveform"
        }
    }
    
    init() {
        Task { @MainActor in await setupPipeline() }
    }
    
    @MainActor
    private func setupPipeline() async {
        if !HotkeyService.hasAccessibilityPermissions() {
            print("[GenZFlow] Requesting accessibility permissions...")
        }
        
        do {
            try await transcriptionService.setup()
            appState.isWhisperReady = true
        } catch {
            print("[GenZFlow] WhisperKit setup failed: \(error)")
            appState.recordingState = .error("Failed to load Whisper model")
            return
        }
        
        hotkeyService.onFnKeyDown = { [weak appState] in
            guard let appState = appState else { return }
            Task { @MainActor in await self.startRecording(appState: appState) }
        }
        hotkeyService.onFnKeyUp = { [weak appState] in
            guard let appState = appState else { return }
            Task { @MainActor in await self.stopRecordingAndProcess(appState: appState) }
        }
        audioService.onRecordingTimeout = { [weak appState] in
            guard let appState = appState else { return }
            Task { @MainActor in await self.stopRecordingAndProcess(appState: appState) }
        }
        
        let started = hotkeyService.start()
        if !started { appState.recordingState = .error("Grant accessibility permissions and restart") }
        print("[GenZFlow] Pipeline ready \u{2014} press Fn to talk!")
    }
    
    @MainActor
    private func startRecording(appState: AppState) async {
        guard appState.recordingState == .idle, appState.isWhisperReady else { return }
        do {
            _ = try audioService.startRecording()
            appState.recordingState = .recording
            NSSound.beep()
        } catch {
            appState.recordingState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    private func stopRecordingAndProcess(appState: AppState) async {
        guard appState.recordingState == .recording else { return }
        guard let audioURL = audioService.stopRecording() else {
            appState.recordingState = .error("No audio captured")
            return
        }
        
        appState.recordingState = .transcribing
        do {
            let transcript = try await transcriptionService.transcribe(audioURL: audioURL)
            appState.originalTranscript = transcript
            appState.recordingState = .translating
            let genZText = try await translationService.translate(transcript)
            pasteService.paste(genZText)
            appState.lastTranslation = genZText
            appState.translationCount += 1
            appState.recordingState = .done(genZText)
            audioService.cleanup()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            appState.recordingState = .idle
        } catch {
            appState.recordingState = .error(error.localizedDescription)
            audioService.cleanup()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            appState.recordingState = .idle
        }
    }
}

import SwiftUI
import AppKit

@main
struct GenZFlowApp: App {
    @StateObject private var controller = AppController()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: controller.appState, onStyleChanged: { style in
                controller.setStyle(style)
            }, onRecordToggle: {
                controller.toggleRecording()
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
    }
    
    private var menuBarIcon: String {
        switch controller.appState.recordingState {
        case .recording: return "mic.fill"
        case .transcribing, .translating: return "brain.head.profile"
        case .error: return "exclamationmark.triangle"
        default: return "waveform"
        }
    }

}

@MainActor
final class AppController: ObservableObject {
    let appState = AppState()

    private let hotkeyService = HotkeyService()
    private let audioService = AudioService()
    private let transcriptionService = TranscriptionService()
    private let translationService = TranslationService()
    private let pasteService = PasteService()
    private var lastExternalApp: NSRunningApplication?
    private var activePasteTarget = PasteTarget(app: nil, focusedElement: nil)

    init() {
        lastExternalApp = currentTargetApp()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in
                self?.lastExternalApp = app
            }
        }

        Task { @MainActor in
            await setupPipeline()
        }
    }

    func setStyle(_ style: SlangStyle) {
        translationService.currentStyle = style
    }

    func toggleRecording() {
        Task { @MainActor in
            switch appState.recordingState {
            case .idle:
                await startRecording(appState: appState)
            case .recording:
                await stopRecordingAndProcess(appState: appState)
            default:
                break
            }
        }
    }

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
        
        hotkeyService.onFnKeyDown = { [weak self] in
            self?.toggleRecording()
        }
        hotkeyService.onFnKeyUp = {}
        audioService.onRecordingTimeout = { [weak appState] in
            guard let appState = appState else { return }
            Task { @MainActor in await self.stopRecordingAndProcess(appState: appState) }
        }
        
        let started = hotkeyService.start()
        if !started { appState.recordingState = .error("Grant accessibility permissions and restart") }
        print("[GenZFlow] Pipeline ready — press Control + Option + Space to toggle recording")
    }
    
    private func startRecording(appState: AppState) async {
        guard appState.recordingState == .idle, appState.isWhisperReady else { return }
        do {
            activePasteTarget = pasteService.captureTarget(for: currentTargetApp())
            _ = try audioService.startRecording()
            appState.recordingState = .recording
            NSSound.beep()
        } catch {
            appState.recordingState = .error(error.localizedDescription)
        }
    }
    
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
            pasteService.paste(genZText, into: activePasteTarget)
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

    private func currentTargetApp() -> NSRunningApplication? {
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        if currentFrontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            return currentFrontmost
        }
        return lastExternalApp
    }
}

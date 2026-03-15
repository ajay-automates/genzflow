import Foundation
import AVFoundation

class AudioService {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private var isRecording = false
    private var recordingTimer: Timer?
    var onRecordingTimeout: (() -> Void)?
    
    func startRecording() throws -> URL {
        guard !isRecording else { throw AudioError.alreadyRecording }
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("genzflow_\(UUID().uuidString).wav")
        guard let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Config.audioSampleRate, channels: 1, interleaved: false) else { throw AudioError.formatError }
        guard let converter = AVAudioConverter(from: inputFormat, to: recordingFormat) else { throw AudioError.converterError }
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * Config.audioSampleRate / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: frameCount) else { return }
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if status == .haveData { try? audioFile.write(from: convertedBuffer) }
        }
        
        try engine.start()
        self.audioEngine = engine; self.audioFile = audioFile; self.tempFileURL = fileURL; self.isRecording = true
        recordingTimer = Timer.scheduledTimer(withTimeInterval: Config.maxRecordingDuration, repeats: false) { [weak self] _ in self?.onRecordingTimeout?() }
        print("[AudioService] Recording started")
        return fileURL
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        recordingTimer?.invalidate(); recordingTimer = nil
        isRecording = false
        audioEngine?.inputNode.removeTap(onBus: 0); audioEngine?.stop(); audioEngine = nil; audioFile = nil
        print("[AudioService] Recording stopped")
        return tempFileURL
    }
    
    func cleanup() { if let url = tempFileURL { try? FileManager.default.removeItem(at: url); tempFileURL = nil } }
    deinit { if isRecording { _ = stopRecording() }; cleanup() }
}

enum AudioError: LocalizedError {
    case alreadyRecording, formatError, converterError
    var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "Already recording"
        case .formatError: return "Failed to create audio format"
        case .converterError: return "Failed to create audio converter"
        }
    }
}

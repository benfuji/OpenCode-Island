//
//  SpeechService.swift
//  OpenCodeIsland
//
//  Speech-to-text service using WhisperKit for local transcription
//

import AVFoundation
import Combine
import Foundation
import WhisperKit

/// State of the speech service
enum SpeechServiceState: Equatable {
    case idle
    case loading          // Loading/downloading model
    case ready            // Model loaded, ready to record
    case recording        // Currently recording audio
    case transcribing     // Processing recorded audio
    case error(String)
    
    var isReady: Bool {
        self == .ready
    }
    
    var isRecording: Bool {
        self == .recording
    }
}

/// Service for local speech-to-text using WhisperKit
@MainActor
class SpeechService: ObservableObject {
    static let shared = SpeechService()
    
    // MARK: - Published State
    
    @Published private(set) var state: SpeechServiceState = .idle
    @Published private(set) var loadingProgress: String = ""
    @Published private(set) var currentModelName: String = ""
    
    /// Current audio level (0.0 to 1.0) for waveform visualization
    @Published private(set) var audioLevel: Float = 0.0
    
    // MARK: - Private Properties
    
    private var whisperKit: WhisperKit?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var loadedModel: WhisperModel?
    private var levelTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Model Management
    
    /// Load the WhisperKit model (downloads if needed)
    func loadModel() async {
        let targetModel = AppSettings.whisperModel
        
        // Skip if already loaded with same model
        if whisperKit != nil && loadedModel == targetModel {
            state = .ready
            return
        }
        
        state = .loading
        loadingProgress = "Initializing WhisperKit..."
        currentModelName = targetModel.displayName
        
        do {
            loadingProgress = "Loading \(targetModel.displayName)..."
            
            let config = WhisperKitConfig(
                model: targetModel.rawValue,
                verbose: false,
                logLevel: .none
            )
            
            whisperKit = try await WhisperKit(config)
            loadedModel = targetModel
            state = .ready
            loadingProgress = ""
            
            print("[SpeechService] Model loaded: \(targetModel.rawValue)")
        } catch {
            state = .error("Failed to load model: \(error.localizedDescription)")
            loadingProgress = ""
            print("[SpeechService] Error loading model: \(error)")
        }
    }
    
    /// Reload model if settings changed
    func reloadModelIfNeeded() async {
        let targetModel = AppSettings.whisperModel
        if loadedModel != targetModel {
            await loadModel()
        }
    }
    
    // MARK: - Recording
    
    /// Start recording audio from microphone
    func startRecording() async -> Bool {
        guard state == .ready else {
            print("[SpeechService] Cannot start recording - not ready (state: \(state))")
            return false
        }
        
        // Request microphone permission if needed
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            state = .error("Microphone permission denied")
            return false
        }
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "whisper_recording_\(UUID().uuidString).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let recordingURL = recordingURL else {
            state = .error("Failed to create recording file")
            return false
        }
        
        // Configure audio session and recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,  // WhisperKit expects 16kHz
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            state = .recording
            
            // Start audio level monitoring
            startLevelMonitoring()
            
            print("[SpeechService] Recording started")
            return true
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
            print("[SpeechService] Recording error: \(error)")
            return false
        }
    }
    
    /// Stop recording and transcribe the audio
    func stopRecordingAndTranscribe() async -> String? {
        guard state == .recording, let recorder = audioRecorder, let url = recordingURL else {
            print("[SpeechService] Cannot stop recording - not recording")
            return nil
        }
        
        stopLevelMonitoring()
        recorder.stop()
        audioRecorder = nil
        state = .transcribing
        audioLevel = 0.0
        
        defer {
            // Clean up recording file
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
            state = .ready
        }
        
        guard let whisper = whisperKit else {
            state = .error("WhisperKit not initialized")
            return nil
        }
        
        do {
            print("[SpeechService] Transcribing audio...")
            let results = try await whisper.transcribe(audioPath: url.path)
            let transcription = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            print("[SpeechService] Transcription: \(transcription)")
            return transcription.isEmpty ? nil : transcription
        } catch {
            print("[SpeechService] Transcription error: \(error)")
            return nil
        }
    }
    
    /// Cancel recording without transcribing
    func cancelRecording() {
        stopLevelMonitoring()
        audioRecorder?.stop()
        audioRecorder = nil
        audioLevel = 0.0
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        
        if state == .recording || state == .transcribing {
            state = .ready
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        
        // Get average power in decibels (-160 to 0)
        let avgPower = recorder.averagePower(forChannel: 0)
        
        // Convert to linear scale (0.0 to 1.0)
        // -60 dB is considered silence, 0 dB is max
        let minDb: Float = -60.0
        let normalizedLevel = max(0.0, (avgPower - minDb) / (-minDb))
        
        // Apply some smoothing and boost for visual appeal
        let boostedLevel = pow(normalizedLevel, 0.5) // Square root to boost quieter sounds
        audioLevel = min(1.0, boostedLevel * 1.2)
    }
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

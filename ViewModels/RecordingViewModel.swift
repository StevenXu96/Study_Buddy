import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var recordingDuration = "00:00"
    @Published var processingStatus = ""
    @Published var errorMessage: String?
    @Published var showingSummary = false
    @Published var generatedSummary: StudySummary?
    @Published var pulseAnimation = false
    
    // MARK: - Services
    private let audioRecorder = AudioRecorderService()
    private let transcriptionService = TranscriptionService()
    private let summaryService = SummaryGeneratorService()
    
    // MARK: - Private Properties
    private var recordingSession: RecordingSession?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind audio recorder errors
        audioRecorder.$errorMessage
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permissions
    func requestMicrophonePermission() {
        audioRecorder.requestPermission { [weak self] granted in
            if !granted {
                Task { @MainActor in
                    self?.errorMessage = "Microphone permission is required to record study sessions."
                }
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() {
        errorMessage = nil
        
        guard audioRecorder.startRecording() else {
            errorMessage = "Failed to start recording. Please check microphone permissions."
            return
        }
        
        isRecording = true
        pulseAnimation = true
        
        let startTime = Date()
        recordingSession = RecordingSession(
            startTime: startTime,
            endTime: nil,
            audioFileURL: audioRecorder.currentRecordingURL!
        )
        
        // Start timer for duration display
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
    }
    
    func stopRecording() {
        audioRecorder.stopRecording()
        isRecording = false
        pulseAnimation = false
        timer?.invalidate()
        timer = nil
        
        recordingSession?.endTime = Date()
        
        // Start processing
        Task {
            await processRecording()
        }
    }
    
    private func updateRecordingDuration() {
        guard let session = recordingSession else { return }
        
        let duration = Date().timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            recordingDuration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            recordingDuration = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Processing
    private func processRecording() async {
        guard let session = recordingSession else {
            errorMessage = "No recording session found."
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            // Step 1: Transcribe audio
            processingStatus = "Transcribing audio..."
            let transcription = try await transcriptionService.transcribe(audioURL: session.audioFileURL)
            
            print("📝 Transcription completed:")
            print("📝 Text: \(transcription.text)")
            print("📝 Word count: \(transcription.wordCount)")
            print("📝 Is valid: \(transcription.isValid)")
            
            guard transcription.isValid else {
                throw NSError(domain: "StudyBuddy", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Transcription too short. Please record a longer session."
                ])
            }
            
            // Step 2: Generate summary
            processingStatus = "Generating summary..."
            let summary = try await summaryService.generateSummary(
                transcript: transcription.text,
                duration: session.durationFormatted
            )
            
            // Step 3: Show results
            generatedSummary = summary
            showingSummary = true
            isProcessing = false
            processingStatus = ""
            
        } catch {
            isProcessing = false
            processingStatus = ""
            errorMessage = "Processing failed: \(error.localizedDescription)"
        }
    }
}

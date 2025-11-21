import Foundation
import AVFoundation

class AudioRecorderService: NSObject, ObservableObject {
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    private(set) var currentRecordingURL: URL?
    
    // MARK: - Permissions
    func requestPermission(completion: @escaping (Bool) -> Void) {
        print("🎤 Requesting microphone permission...")
        
        // Force request by trying to create a capture device
        // This triggers the permission dialog on macOS
        if AVCaptureDevice.default(for: .audio) != nil {
            print("🎤 Audio device found")
        }
        
        // Check authorization status
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 Current status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("🎤 Already authorized")
            completion(true)
        case .notDetermined:
            print("🎤 Not determined, requesting access...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("🎤 Access granted: \(granted)")
                DispatchQueue.main.async {
                    if !granted {
                        self.errorMessage = "Microphone access denied. Please enable in System Settings → Privacy & Security → Microphone"
                    }
                    completion(granted)
                }
            }
        case .denied:
            print("🎤 Permission denied")
            self.errorMessage = "Microphone access denied. Please enable in System Settings → Privacy & Security → Microphone"
            completion(false)
        case .restricted:
            print("🎤 Permission restricted")
            self.errorMessage = "Microphone access is restricted"
            completion(false)
        @unknown default:
            print("🎤 Unknown permission status")
            completion(false)
        }
    }
    
    // MARK: - Recording
    func startRecording() -> Bool {
        // Create unique filename
        let filename = "recording_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent(filename)
        
        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                currentRecordingURL = audioFilename
                errorMessage = nil
            } else {
                errorMessage = "Failed to start recording"
            }
            
            return success
        } catch {
            errorMessage = "Recording failed: \(error.localizedDescription)"
            return false
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
    }
    
    // MARK: - Cleanup
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "Recording was not completed successfully"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            errorMessage = "Encoding error: \(error.localizedDescription)"
        }
    }
}

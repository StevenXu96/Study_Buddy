import Foundation
import Speech

class TranscriptionService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    // MARK: - Main Transcription Method
    // Transcription mode determined by user settings
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        let mode = UserDefaults.standard.string(forKey: "transcriptionMode") ?? "local"
        
        if mode == "whisper" {
            // Use OpenAI Whisper API (better for technical/medical terms)
            return try await transcribeWithWhisper(audioURL: audioURL)
        } else {
            // Use Apple Speech Framework (default, free, private)
            return try await transcribeWithAppleSpeech(audioURL: audioURL)
        }
    }
    
    // MARK: - OpenAI Whisper API Transcription
    private func transcribeWithWhisper(audioURL: URL) async throws -> TranscriptionResult {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            throw NSError(domain: "StudyBuddy", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured. Please add it in Settings."
            ])
        }
        
        // Read audio file
        let audioData = try Data(contentsOf: audioURL)
        
        print("📤 Uploading audio to OpenAI Whisper (size: \(audioData.count / 1_000_000)MB)...")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600 // 10 minutes for large files
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add language parameter (optional, helps with accuracy)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Whisper API error: \(errorMessage)")
            throw NSError(domain: "StudyBuddy", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Whisper transcription failed. Please check your API key and try again."
            ])
        }
        
        // Parse response
        struct WhisperResponse: Codable {
            let text: String
        }
        
        let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        
        print("✅ Whisper transcription complete")
        
        // Calculate word count
        let words = whisperResponse.text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        return TranscriptionResult(
            text: whisperResponse.text,
            duration: 0, // Duration not provided by Whisper API
            wordCount: words.count
        )
    }
    
    // MARK: - Apple Speech Framework Transcription
    private func transcribeWithAppleSpeech(audioURL: URL) async throws -> TranscriptionResult {
        // Request authorization
        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            throw NSError(domain: "StudyBuddy", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Speech recognition not authorized"
            ])
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "StudyBuddy", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Speech recognizer not available"
            ])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true // Force local processing
            
            // Add context for better recognition of technical terms
            request.contextualStrings = [
                // Medical terms
                "photosynthesis", "mitochondria", "ATP", "chloroplast", "glucose",
                "myocardial", "infarction", "pneumothorax", "acetylcholine",
                "hemoglobin", "leukocyte", "erythrocyte", "thrombocyte",
                // Add more terms as needed
            ]
            
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    let transcription = result.bestTranscription
                    let duration = transcription.segments.last?.timestamp ?? 0
                    let wordCount = transcription.segments.count
                    
                    let transcriptionResult = TranscriptionResult(
                        text: transcription.formattedString,
                        duration: duration,
                        wordCount: wordCount
                    )
                    
                    continuation.resume(returning: transcriptionResult)
                }
            }
        }
    }
    
    // MARK: - Authorization
    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

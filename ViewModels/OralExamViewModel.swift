import Foundation
import AVFoundation
import SwiftUI

@MainActor
class OralExamViewModel: ObservableObject {
    @Published var oralQuestion: OralExamQuestion?
    @Published var isGeneratingQuestion = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isEvaluated = false
    @Published var recordingDuration = "00:00"
    @Published var processingStatus = ""
    @Published var errorMessage: String?
    @Published var pulseAnimation = false
    @Published var answerTranscription = ""
    @Published var evaluation: OralExamEvaluation?
    
    private let summary: StudySummary
    private let audioRecorder = AudioRecorderService()
    private let transcriptionService = TranscriptionService()
    private var recordingStartTime: Date?
    private var timer: Timer?
    
    init(summary: StudySummary) {
        self.summary = summary
    }
    
    func requestMicrophonePermission() {
        audioRecorder.requestPermission { [weak self] granted in
            if !granted {
                Task { @MainActor in
                    self?.errorMessage = "Microphone permission is required for oral examination."
                }
            }
        }
    }
    
    // MARK: - Question Generation
    
    func generateQuestion() async {
        isGeneratingQuestion = true
        errorMessage = nil
        
        do {
            let mode = UserDefaults.standard.string(forKey: "processingMode") ?? "builtin"
            
            let prompt = """
            You are a Canadian Royal College medical examiner conducting an oral examination. Based on the following study session material, create 1 comprehensive oral exam question in the Royal College examination style. Difficulty level should be medium to hard. 
            
            STUDY MATERIAL:
            Summary: \(summary.summaryText)
            
            Key Points:
            \(summary.keyPoints.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))
            
            REQUIREMENTS:
            - Question must be Royal College oral exam style: open-ended, requiring detailed verbal explanation
            - Should test clinical reasoning, diagnostic approach, management, or conceptual understanding
            - Include a clinical scenario or context where appropriate
            - Question should be answerable based on the study material
            - Model answer should be comprehensive but conversational (as if spoken in exam)
            
            You MUST respond with ONLY valid JSON in this exact format:
            {
              "question": "Question text here",
              "context": "Clinical scenario or case details",
              "modelAnswer": "Comprehensive spoken-style answer covering all key points an examiner would expect"
            }
            
            CRITICAL: Your response must be ONLY the JSON object.
            """
            
            let question: OralExamQuestion
            
            switch mode {
            case "cloud":
                question = try await generateQuestionWithOpenAI(prompt: prompt)
            case "ollama":
                question = try await generateQuestionWithOllama(prompt: prompt)
            default:
                question = generateQuestionLocally()
            }
            
            self.oralQuestion = question
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isGeneratingQuestion = false
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
        recordingStartTime = Date()
        
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
        
        Task {
            await processAnswer()
        }
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        recordingDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Answer Processing
    
    private func processAnswer() async {
        guard let audioURL = audioRecorder.currentRecordingURL else {
            errorMessage = "No recording found."
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            // Step 1: Transcribe answer
            processingStatus = "Transcribing your answer..."
            let transcription = try await transcriptionService.transcribe(audioURL: audioURL)
            
            guard transcription.isValid else {
                throw NSError(domain: "StudyBuddy", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Answer too short. Please provide a more comprehensive response."
                ])
            }
            
            answerTranscription = transcription.text
            
            // Step 2: Evaluate answer
            processingStatus = "Evaluating your answer..."
            let evaluation = try await evaluateAnswer(transcription: transcription.text)
            
            self.evaluation = evaluation
            isEvaluated = true
            isProcessing = false
            processingStatus = ""
            
        } catch {
            isProcessing = false
            processingStatus = ""
            errorMessage = "Failed to process answer: \(error.localizedDescription)"
        }
    }
    
    private func evaluateAnswer(transcription: String) async throws -> OralExamEvaluation {
        guard let question = oralQuestion else {
            throw NSError(domain: "StudyBuddy", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "No question available"
            ])
        }
        
        let mode = UserDefaults.standard.string(forKey: "processingMode") ?? "builtin"
        
        let prompt = """
        You are a Canadian Royal College medical examiner evaluating an oral exam answer.
        
        QUESTION:
        \(question.question)
        
        CLINICAL CONTEXT:
        \(question.context)
        
        MODEL ANSWER:
        \(question.modelAnswer)
        
        CANDIDATE'S ANSWER (Transcribed):
        \(transcription)
        
        Evaluate the answer and provide:
        1. A score from 0-100
        2. List of strengths (what they got right)
        3. List of areas for improvement (what they missed or could improve)
        4. Overall feedback suitable for a Royal College oral exam
        
        You MUST respond with ONLY valid JSON in this exact format:
        {
          "score": 85,
          "strengths": [
            "Strength 1",
            "Strength 2"
          ],
          "areasForImprovement": [
            "Area 1",
            "Area 2"
          ],
          "overallFeedback": "Comprehensive feedback on the candidate's performance"
        }
        
        CRITICAL: Your response must be ONLY the JSON object.
        """
        
        switch mode {
        case "cloud":
            return try await evaluateWithOpenAI(prompt: prompt)
        case "ollama":
            return try await evaluateWithOllama(prompt: prompt)
        default:
            return evaluateLocally(transcription: transcription)
        }
    }
    
    // MARK: - AI Methods
    
    private func generateQuestionWithOpenAI(prompt: String) async throws -> OralExamQuestion {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured"
            ])
        }
        
        let model = UserDefaults.standard.string(forKey: "modelSelection") ?? "gpt-4"
        
        let messages = [
            OpenAIMessage(role: "system", content: "You are a Canadian Royal College medical examiner."),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            maxTokens: 1500
        )
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StudyBuddy", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API request failed"
            ])
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw NSError(domain: "StudyBuddy", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse OpenAI response"
            ])
        }
        
        return try parseQuestion(from: content)
    }
    
    private func generateQuestionWithOllama(prompt: String) async throws -> OralExamQuestion {
        let ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        let model = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2"
        
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]
        
        guard let url = URL(string: "\(ollamaURL)/api/generate") else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Ollama URL"
            ])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 900
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StudyBuddy", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Ollama request failed"
            ])
        }
        
        struct OllamaResponse: Codable {
            let response: String
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return try parseQuestion(from: ollamaResponse.response)
    }
    
    private func evaluateWithOpenAI(prompt: String) async throws -> OralExamEvaluation {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured"
            ])
        }
        
        let model = UserDefaults.standard.string(forKey: "modelSelection") ?? "gpt-4"
        
        let messages = [
            OpenAIMessage(role: "system", content: "You are a Canadian Royal College medical examiner."),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: messages,
            temperature: 0.3,
            maxTokens: 1500
        )
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StudyBuddy", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API request failed"
            ])
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw NSError(domain: "StudyBuddy", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse OpenAI response"
            ])
        }
        
        return try parseEvaluation(from: content)
    }
    
    private func evaluateWithOllama(prompt: String) async throws -> OralExamEvaluation {
        let ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        let model = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2"
        
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]
        
        guard let url = URL(string: "\(ollamaURL)/api/generate") else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Ollama URL"
            ])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 900
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StudyBuddy", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Ollama request failed"
            ])
        }
        
        struct OllamaResponse: Codable {
            let response: String
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return try parseEvaluation(from: ollamaResponse.response)
    }
    
    // MARK: - Local Fallback
    
    private func generateQuestionLocally() -> OralExamQuestion {
        return OralExamQuestion(
            question: "Please explain the main concepts we discussed and their clinical significance.",
            context: "Consider the key points from your study session: \(summary.keyPoints.prefix(2).joined(separator: "; "))",
            modelAnswer: "A comprehensive answer would discuss: \(summary.keyPoints.joined(separator: "; "))"
        )
    }
    
    private func evaluateLocally(transcription: String) -> OralExamEvaluation {
        let wordCount = transcription.split(separator: " ").count
        let score = min(100, max(40, wordCount * 2))
        
        return OralExamEvaluation(
            score: score,
            strengths: ["Provided verbal response", "Attempted to answer the question"],
            areasForImprovement: ["Consider using AI evaluation for detailed feedback"],
            overallFeedback: "Your answer has been transcribed. For detailed evaluation, consider enabling AI-powered assessment in settings."
        )
    }
    
    // MARK: - Parsing Helpers
    
    private func parseQuestion(from content: String) throws -> OralExamQuestion {
        var cleanContent = content
        if cleanContent.contains("```json") {
            cleanContent = cleanContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        struct QuestionData: Codable {
            let question: String
            let context: String
            let modelAnswer: String
        }
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "StudyBuddy", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse question data"
            ])
        }
        
        let data = try JSONDecoder().decode(QuestionData.self, from: jsonData)
        
        return OralExamQuestion(
            question: data.question,
            context: data.context,
            modelAnswer: data.modelAnswer
        )
    }
    
    private func parseEvaluation(from content: String) throws -> OralExamEvaluation {
        var cleanContent = content
        if cleanContent.contains("```json") {
            cleanContent = cleanContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        struct EvaluationData: Codable {
            let score: Int
            let strengths: [String]
            let areasForImprovement: [String]
            let overallFeedback: String
        }
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "StudyBuddy", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse evaluation data"
            ])
        }
        
        let data = try JSONDecoder().decode(EvaluationData.self, from: jsonData)
        
        return OralExamEvaluation(
            score: data.score,
            strengths: data.strengths,
            areasForImprovement: data.areasForImprovement,
            overallFeedback: data.overallFeedback
        )
    }
}

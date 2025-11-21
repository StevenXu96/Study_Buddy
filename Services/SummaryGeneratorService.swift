import Foundation

class SummaryGeneratorService {
    private let localAIService = LocalAIService()
    
    // MARK: - Main Summary Generation
    func generateSummary(transcript: String, duration: String) async throws -> StudySummary {
        let mode = UserDefaults.standard.string(forKey: "processingMode") ?? "builtin"
        
        switch mode {
        case "cloud":
            return try await generateWithOpenAI(transcript: transcript, duration: duration)
        case "ollama":
            return try await generateWithOllama(transcript: transcript, duration: duration)
        default: // "builtin"
            return try await generateLocally(transcript: transcript, duration: duration)
        }
    }
    
    // MARK: - Ollama Generation (Local HTTP Server)
    private func generateWithOllama(transcript: String, duration: String) async throws -> StudySummary {
        let ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        let model = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2"
        
        let prompt = """
        You are an expert educational assistant. Analyze the following study session transcript.
        
        TRANSCRIPT:
        \(transcript)
        
        You MUST respond with ONLY valid JSON in this exact format (no other text, no markdown, no explanations):
        
        {
          "summary": "A 200-300 word summary of the main topics and concepts",
          "keyPoints": ["Key point 1", "Key point 2", "Key point 3", "Key point 4", "Key point 5"],
          "quizQuestions": [
            {"question": "Question 1?", "answer": "Answer to question 1"},
            {"question": "Question 2?", "answer": "Answer to question 2"},
            {"question": "Question 3?", "answer": "Answer to question 3"},
            {"question": "Question 4?", "answer": "Answer to question 4"},
            {"question": "Question 5?", "answer": "Answer to question 5"}
          ]
        }
        
        CRITICAL: Your response must be ONLY the JSON object above. Do not include any other text before or after the JSON.
        """
        
        // Create Ollama request
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
        request.timeoutInterval = 900 // 15 minutes for long responses
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StudyBuddy", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Ollama request failed. Make sure Ollama is running (ollama serve)"
            ])
        }
        
        // Parse Ollama response
        struct OllamaResponse: Codable {
            let response: String
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        
        // Parse the JSON response from the model
        return try parseAIResponse(content: ollamaResponse.response, duration: duration)
    }
    
    // MARK: - Cloud Generation (OpenAI)
    private func generateWithOpenAI(transcript: String, duration: String) async throws -> StudySummary {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured. Please add your API key in Settings."
            ])
        }
        
        let model = UserDefaults.standard.string(forKey: "modelSelection") ?? "gpt-4"
        
        // Create prompt
        let prompt = """
        You are an expert educational assistant. Analyze the following study session transcript and create a comprehensive summary.
        
        TRANSCRIPT:
        \(transcript)
        
        Please provide:
        1. A detailed summary (200-300 words) covering the main topics and concepts discussed
        2. 5-7 key points or takeaways
        3. 5-8 quiz questions with answers based on the material
        
        Format your response as JSON with this structure:
        {
          "summary": "detailed summary text here",
          "keyPoints": ["point 1", "point 2", ...],
          "quizQuestions": [
            {"question": "question text", "answer": "answer text"},
            ...
          ]
        }
        
        Make the summary suitable for a 1-2 page document. Ensure questions test understanding, not just memorization.
        """
        
        // Create request
        let messages = [
            OpenAIMessage(role: "system", content: "You are an expert educational assistant that creates study summaries and quiz questions."),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            maxTokens: 2000
        )
        
        // Make API call
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StudyBuddy", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API request failed. Please check your API key and try again."
            ])
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw NSError(domain: "StudyBuddy", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse OpenAI response"
            ])
        }
        
        // Parse JSON from content
        return try parseAIResponse(content: content, duration: duration)
    }
    
    // MARK: - Local Generation
    private func generateLocally(transcript: String, duration: String) async throws -> StudySummary {
        // Use built-in heuristic-based summarization
        return try await localAIService.generateWithHeuristics(
            transcript: transcript,
            duration: duration
        )
    }
    
    // MARK: - Helper Methods
    private func parseAIResponse(content: String, duration: String) throws -> StudySummary {
        // Clean up potential markdown code blocks
        var cleanContent = content
        if cleanContent.contains("```json") {
            cleanContent = cleanContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Parse JSON
        struct AIResponse: Codable {
            let summary: String
            let keyPoints: [String]
            let quizQuestions: [QuizQuestionResponse]
        }
        
        struct QuizQuestionResponse: Codable {
            let question: String
            let answer: String
        }
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "StudyBuddy", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert response to data"
            ])
        }
        
        let aiResponse = try JSONDecoder().decode(AIResponse.self, from: jsonData)
        
        // Convert to app models
        let quizQuestions = aiResponse.quizQuestions.map { q in
            QuizQuestion(question: q.question, answer: q.answer)
        }
        
        return StudySummary(
            duration: duration,
            summaryText: aiResponse.summary,
            keyPoints: aiResponse.keyPoints,
            quizQuestions: quizQuestions
        )
    }
}

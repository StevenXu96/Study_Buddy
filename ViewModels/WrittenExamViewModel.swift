import Foundation
import SwiftUI

@MainActor
class WrittenExamViewModel: ObservableObject {
    @Published var questions: [WrittenExamQuestion] = []
    @Published var userAnswers: [String] = ["", "", ""]
    @Published var isGenerating = false
    @Published var isEvaluating = false
    @Published var isSubmitted = false
    @Published var errorMessage: String?
    @Published var overallFeedback = ""
    
    private let summary: StudySummary
    private let summaryService = SummaryGeneratorService()
    
    var canSubmit: Bool {
        return !userAnswers.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    init(summary: StudySummary) {
        self.summary = summary
        self.userAnswers = ["", "", ""]
    }
    
    func generateQuestions() async {
        isGenerating = true
        errorMessage = nil
        
        print("📝 Starting written exam question generation...")
        
        do {
            let mode = UserDefaults.standard.string(forKey: "processingMode") ?? "builtin"
            print("   Mode: \(mode)")
            
            let prompt = """
            You are a Canadian Royal College medical examiner. Based on the following study session material, create 3 comprehensive written exam questions in the Royal College examination style. Difficulty level should be medium to hard. 
            
            STUDY MATERIAL:
            Summary: \(summary.summaryText)
            
            Key Points:
            \(summary.keyPoints.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))
            
            REQUIREMENTS:
            - Questions must be Royal College style: detailed clinical scenarios requiring comprehensive answers
            - Questions should test clinical reasoning, differential diagnosis, management plans, or pathophysiology
            - Each question should be answerable based on the study material
            - Include relevant clinical context where appropriate
            - Questions should require 3-5 sentence answers demonstrating medical knowledge
            
            You MUST respond with ONLY valid JSON in this exact format:
            {
              "questions": [
                {
                  "question": "Question text here",
                  "context": "Clinical context or case details if applicable",
                  "modelAnswer": "Comprehensive Royal College approved answer covering key points"
                },
                {
                  "question": "Question text here",
                  "context": "Clinical context or case details if applicable",
                  "modelAnswer": "Comprehensive Royal College approved answer covering key points"
                },
                {
                  "question": "Question text here",
                  "context": "Clinical context or case details if applicable",
                  "modelAnswer": "Comprehensive Royal College approved answer covering key points"
                }
              ]
            }
            
            CRITICAL: Your response must be ONLY the JSON object. Do not include any other text.
            """
            
            let generatedQuestions: [WrittenExamQuestion]
            
            switch mode {
            case "cloud":
                print("   Using OpenAI...")
                generatedQuestions = try await generateQuestionsWithOpenAI(prompt: prompt)
            case "ollama":
                print("   Using Ollama...")
                generatedQuestions = try await generateQuestionsWithOllama(prompt: prompt)
            default:
                print("   Using local fallback...")
                generatedQuestions = generateQuestionsLocally()
            }
            
            print("✅ Generated \(generatedQuestions.count) questions")
            
            self.questions = generatedQuestions
            self.userAnswers = Array(repeating: "", count: generatedQuestions.count)
            
        } catch {
            print("❌ Error generating questions: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    func submitAnswers() async {
        isEvaluating = true
        errorMessage = nil
        
        do {
            let mode = UserDefaults.standard.string(forKey: "processingMode") ?? "builtin"
            
            // Build evaluation prompt
            var evaluationPrompt = """
            You are a Canadian Royal College medical examiner. Evaluate the following student answers to Royal College style questions.
            
            For each answer, provide:
            1. A score from 0-100
            2. Specific feedback on what was correct/incorrect
            3. Key points that were missing
            
            """
            
            for (index, question) in questions.enumerated() {
                evaluationPrompt += """
                
                QUESTION \(index + 1):
                \(question.question)
                
                CLINICAL CONTEXT:
                \(question.context)
                
                MODEL ANSWER:
                \(question.modelAnswer)
                
                STUDENT ANSWER:
                \(userAnswers[index].isEmpty ? "[No answer provided]" : userAnswers[index])
                
                """
            }
            
            evaluationPrompt += """
            
            You MUST respond with ONLY valid JSON in this exact format:
            {
              "evaluations": [
                {
                  "score": 85,
                  "feedback": "Detailed feedback for question 1"
                },
                {
                  "score": 70,
                  "feedback": "Detailed feedback for question 2"
                },
                {
                  "score": 90,
                  "feedback": "Detailed feedback for question 3"
                }
              ],
              "overallFeedback": "Overall assessment of the student's performance"
            }
            
            CRITICAL: Your response must be ONLY the JSON object.
            """
            
            let evaluations: QuestionEvaluations
            
            switch mode {
            case "cloud":
                evaluations = try await evaluateWithOpenAI(prompt: evaluationPrompt)
            case "ollama":
                evaluations = try await evaluateWithOllama(prompt: evaluationPrompt)
            default:
                evaluations = evaluateLocally()
            }
            
            // Update questions with scores and feedback
            for (index, evaluation) in evaluations.evaluations.enumerated() {
                if index < questions.count {
                    questions[index].score = evaluation.score
                    questions[index].feedback = evaluation.feedback
                }
            }
            
            overallFeedback = evaluations.overallFeedback
            isSubmitted = true
            
        } catch {
            errorMessage = "Failed to evaluate answers: \(error.localizedDescription)"
        }
        
        isEvaluating = false
    }
    
    func calculateScore() -> Int {
        guard !questions.isEmpty else { return 0 }
        let total = questions.reduce(0) { $0 + $1.score }
        return total / questions.count
    }
    
    // MARK: - AI Generation Methods
    
    private func generateQuestionsWithOpenAI(prompt: String) async throws -> [WrittenExamQuestion] {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured"
            ])
        }
        
        let model = UserDefaults.standard.string(forKey: "modelSelection") ?? "gpt-4"
        
        let messages = [
            OpenAIMessage(role: "system", content: "You are a Canadian Royal College medical examiner creating examination questions."),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            maxTokens: 2000
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
        
        return try parseQuestions(from: content)
    }
    
    private func generateQuestionsWithOllama(prompt: String) async throws -> [WrittenExamQuestion] {
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
        return try parseQuestions(from: ollamaResponse.response)
    }
    
    private func evaluateWithOpenAI(prompt: String) async throws -> QuestionEvaluations {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            throw NSError(domain: "StudyBuddy", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured"
            ])
        }
        
        let model = UserDefaults.standard.string(forKey: "modelSelection") ?? "gpt-4"
        
        let messages = [
            OpenAIMessage(role: "system", content: "You are a Canadian Royal College medical examiner evaluating student answers."),
            OpenAIMessage(role: "user", content: prompt)
        ]
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: messages,
            temperature: 0.3,
            maxTokens: 2000
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
        
        return try parseEvaluations(from: content)
    }
    
    private func evaluateWithOllama(prompt: String) async throws -> QuestionEvaluations {
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
        return try parseEvaluations(from: ollamaResponse.response)
    }
    
    // MARK: - Local Fallback
    
    private func generateQuestionsLocally() -> [WrittenExamQuestion] {
        print("   Generating local fallback questions...")
        
        // Extract key topics from summary
        let keyPoints = summary.keyPoints
        let summaryText = summary.summaryText
        
        // Create clinically relevant questions based on the material
        let questions = [
            WrittenExamQuestion(
                question: "Based on the study material, explain the main concepts discussed and their clinical significance. How would you apply this knowledge in clinical practice?",
                context: keyPoints.isEmpty ? "Review the material covered in your study session." : "Key topics covered: \(keyPoints.prefix(2).joined(separator: ", "))",
                modelAnswer: summaryText.isEmpty ? "A comprehensive answer should cover the main concepts and their practical applications." : "A comprehensive answer would include: \(summaryText.prefix(200))...",
                score: 0,
                feedback: ""
            ),
            WrittenExamQuestion(
                question: "Describe the diagnostic approach or management strategy for the clinical scenario related to your study topic. Include key decision points.",
                context: keyPoints.count > 2 ? "Consider: \(keyPoints[2])" : "Reference the material covered in your session.",
                modelAnswer: keyPoints.count > 3 ? "Key considerations include: \(keyPoints[2]); \(keyPoints[3])" : "Key considerations include a systematic approach based on the study material.",
                score: 0,
                feedback: ""
            ),
            WrittenExamQuestion(
                question: "What are the most important clinical pearls and practical takeaways from this topic? How would you explain this to a colleague?",
                context: "Synthesize the information from your study session into practical advice.",
                modelAnswer: keyPoints.isEmpty ? "Important clinical pearls from this topic." : "Important points include: \(keyPoints.suffix(2).joined(separator: "; "))",
                score: 0,
                feedback: ""
            )
        ]
        
        print("   Created \(questions.count) local questions")
        print("   Question 1: \(questions[0].question.prefix(50))...")
        
        return questions
    }
    
    private func evaluateLocally() -> QuestionEvaluations {
        // Simple local evaluation
        let evaluations = userAnswers.enumerated().map { index, answer in
            let wordCount = answer.split(separator: " ").count
            let score = min(100, max(0, wordCount * 10)) // Simple scoring based on length
            let feedback = wordCount > 10 ? "Your answer addresses the question. Consider adding more clinical details." : "Answer is too brief. Provide more comprehensive explanation."
            return QuestionEvaluation(score: score, feedback: feedback)
        }
        
        return QuestionEvaluations(
            evaluations: evaluations,
            overallFeedback: "Answers reviewed. For best results, consider using AI-powered evaluation in settings."
        )
    }
    
    // MARK: - Parsing Helpers
    
    private func parseQuestions(from content: String) throws -> [WrittenExamQuestion] {
        var cleanContent = content
        if cleanContent.contains("```json") {
            cleanContent = cleanContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        struct QuestionResponse: Codable {
            let questions: [QuestionData]
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
        
        let response = try JSONDecoder().decode(QuestionResponse.self, from: jsonData)
        
        let questions = response.questions.map { q in
            WrittenExamQuestion(
                question: q.question,
                context: q.context,
                modelAnswer: q.modelAnswer,
                score: 0,
                feedback: ""
            )
        }
        
        print("   Parsed questions from JSON:")
        for (index, q) in questions.enumerated() {
            print("   Question \(index + 1): '\(q.question.prefix(50))...'")
            print("   Context: '\(q.context.prefix(30))...'")
        }
        
        return questions
    }
    
    private func parseEvaluations(from content: String) throws -> QuestionEvaluations {
        var cleanContent = content
        if cleanContent.contains("```json") {
            cleanContent = cleanContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        struct EvaluationResponse: Codable {
            let evaluations: [EvaluationData]
            let overallFeedback: String
        }
        
        struct EvaluationData: Codable {
            let score: Int
            let feedback: String
        }
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw NSError(domain: "StudyBuddy", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse evaluation data"
            ])
        }
        
        let response = try JSONDecoder().decode(EvaluationResponse.self, from: jsonData)
        
        let evaluations = response.evaluations.map { e in
            QuestionEvaluation(score: e.score, feedback: e.feedback)
        }
        
        return QuestionEvaluations(
            evaluations: evaluations,
            overallFeedback: response.overallFeedback
        )
    }
}

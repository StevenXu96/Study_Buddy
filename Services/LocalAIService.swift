import Foundation
import NaturalLanguage

class LocalAIService {
    
    // MARK: - Local LLM Model (GGUF)
    func generateWithLocalModel(transcript: String, duration: String, modelPath: String) async throws -> StudySummary {
        // GGUF model integration is complex - fall back to built-in heuristics
        // User can use cloud mode (OpenAI) if they need better quality
        print("ℹ️ Using built-in heuristics (GGUF support requires additional setup)")
        return try await generateWithHeuristics(transcript: transcript, duration: duration)
    }
    
    // MARK: - Heuristic-Based Summarization (No External Model)
    func generateWithHeuristics(transcript: String, duration: String) async throws -> StudySummary {
        // Use NaturalLanguage framework for basic analysis
        
        // 1. Extract key sentences
        let sentences = extractSentences(from: transcript)
        
        // 2. Identify important sentences using TF-IDF-like scoring
        let importantSentences = rankSentencesByImportance(sentences: sentences, topN: 10)
        
        // 3. Create summary from top sentences
        let summary = createSummary(from: importantSentences)
        
        // 4. Extract key points
        let keyPoints = extractKeyPoints(from: sentences)
        
        // 5. Generate quiz questions
        let quizQuestions = generateQuizQuestions(from: sentences)
        
        return StudySummary(
            duration: duration,
            summaryText: summary,
            keyPoints: keyPoints,
            quizQuestions: quizQuestions
        )
    }
    
    // MARK: - Text Analysis Helpers
    
    private func extractSentences(from text: String) -> [String] {
        var sentences: [String] = []
        
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty && sentence.count > 20 { // Filter very short sentences
                sentences.append(sentence)
            }
            return true
        }
        
        return sentences
    }
    
    private func rankSentencesByImportance(sentences: [String], topN: Int) -> [String] {
        // Simple importance scoring based on:
        // 1. Length (medium-length sentences often more informative)
        // 2. Presence of important words
        // 3. Position (first and last sentences often important)
        
        let importantKeywords = [
            "because", "therefore", "thus", "however", "important", "key", "main",
            "result", "conclusion", "finding", "shows", "demonstrates", "indicates",
            "significant", "critical", "essential", "fundamental", "primary"
        ]
        
        struct ScoredSentence {
            let sentence: String
            let score: Double
        }
        
        var scored: [ScoredSentence] = []
        
        for (index, sentence) in sentences.enumerated() {
            var score = 0.0
            
            // Length score (prefer 50-150 characters)
            let length = sentence.count
            if length >= 50 && length <= 150 {
                score += 2.0
            } else if length > 150 && length <= 250 {
                score += 1.0
            }
            
            // Keyword score
            let lowerSentence = sentence.lowercased()
            for keyword in importantKeywords {
                if lowerSentence.contains(keyword) {
                    score += 1.5
                }
            }
            
            // Position score
            if index < 3 {
                score += 1.0 // Early sentences
            }
            if index >= sentences.count - 3 {
                score += 0.5 // Late sentences
            }
            
            // Question sentences get lower score
            if sentence.contains("?") {
                score -= 1.0
            }
            
            scored.append(ScoredSentence(sentence: sentence, score: score))
        }
        
        // Sort by score and take top N
        let topSentences = scored
            .sorted { $0.score > $1.score }
            .prefix(topN)
            .map { $0.sentence }
        
        return Array(topSentences)
    }
    
    private func createSummary(from sentences: [String]) -> String {
        // Combine top sentences into a coherent summary
        let summaryText = sentences.prefix(8).joined(separator: " ")
        
        // Ensure it's not too long (aim for 200-400 words)
        let words = summaryText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count > 400 {
            let trimmed = words.prefix(400).joined(separator: " ")
            return trimmed + "..."
        }
        
        return summaryText
    }
    
    private func extractKeyPoints(from sentences: [String]) -> [String] {
        // Extract 5-7 key points
        
        // Look for sentences with key indicators
        let keyPointIndicators = [
            "first", "second", "third", "finally", "importantly",
            "key", "main", "primary", "essential", "critical"
        ]
        
        var keyPoints: [String] = []
        
        for sentence in sentences {
            let lower = sentence.lowercased()
            
            // Check for numbered points
            if lower.matches(of: /^\d+\./).count > 0 {
                keyPoints.append(sentence)
                continue
            }
            
            // Check for bullet indicators
            for indicator in keyPointIndicators {
                if lower.contains(indicator) && keyPoints.count < 7 {
                    keyPoints.append(sentence)
                    break
                }
            }
            
            if keyPoints.count >= 7 {
                break
            }
        }
        
        // If we don't have enough, add more high-scoring sentences
        if keyPoints.count < 5 {
            let additional = rankSentencesByImportance(sentences: sentences, topN: 7)
            for sentence in additional {
                if !keyPoints.contains(sentence) {
                    keyPoints.append(sentence)
                }
                if keyPoints.count >= 7 {
                    break
                }
            }
        }
        
        return Array(keyPoints.prefix(7))
    }
    
    private func generateQuizQuestions(from sentences: [String]) -> [QuizQuestion] {
        // Generate questions from statements
        var questions: [QuizQuestion] = []
        
        // Look for definitional sentences
        for sentence in sentences {
            // Pattern: "X is/are Y"
            if let question = convertToDefinitionQuestion(sentence: sentence) {
                questions.append(question)
                if questions.count >= 8 { break }
            }
        }
        
        // Look for causal sentences
        for sentence in sentences where questions.count < 8 {
            if let question = convertToCausalQuestion(sentence: sentence) {
                questions.append(question)
            }
        }
        
        // Generate "what" questions from key sentences
        for sentence in sentences.prefix(15) where questions.count < 8 {
            if let question = convertToWhatQuestion(sentence: sentence) {
                questions.append(question)
            }
        }
        
        return Array(questions.prefix(8))
    }
    
    private func convertToDefinitionQuestion(sentence: String) -> QuizQuestion? {
        // Convert "X is Y" to "What is X?" with answer "Y"
        let patterns = [
            /(.+?)\s+is\s+(.+)/,
            /(.+?)\s+are\s+(.+)/,
            /(.+?)\s+refers to\s+(.+)/,
            /(.+?)\s+means\s+(.+)/
        ]
        
        for pattern in patterns {
            if let match = sentence.firstMatch(of: pattern) {
                let subject = String(match.1).trimmingCharacters(in: .whitespaces)
                let definition = String(match.2).trimmingCharacters(in: .whitespaces)
                
                let question = "What is \(subject)?"
                let answer = "\(subject.capitalized) is \(definition)"
                
                return QuizQuestion(question: question, answer: answer)
            }
        }
        
        return nil
    }
    
    private func convertToCausalQuestion(sentence: String) -> QuizQuestion? {
        // Convert "X because Y" to "Why does X?" with answer "Y"
        if let range = sentence.range(of: "because", options: .caseInsensitive) {
            let effect = String(sentence[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let cause = String(sentence[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            let question = "Why \(effect.lowercased())?"
            let answer = "Because \(cause)"
            
            return QuizQuestion(question: question, answer: answer)
        }
        
        return nil
    }
    
    private func convertToWhatQuestion(sentence: String) -> QuizQuestion? {
        // Simple fallback: create a "What" question from the sentence
        if sentence.count > 50 && sentence.count < 200 {
            let question = "What was discussed about \(extractMainSubject(from: sentence))?"
            return QuizQuestion(question: question, answer: sentence)
        }
        return nil
    }
    
    private func extractMainSubject(from sentence: String) -> String {
        // Extract first noun phrase as subject
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        
        var subject = "this topic"
        
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                            unit: .word,
                            scheme: .lexicalClass) { tag, range in
            if tag == .noun {
                subject = String(sentence[range])
                return false // Stop after first noun
            }
            return true
        }
        
        return subject
    }
    
    // MARK: - Parse Model Response
    private func parseModelResponse(response: String, duration: String) throws -> StudySummary {
        // Clean up markdown code blocks
        var cleanResponse = response
        if cleanResponse.contains("```json") {
            cleanResponse = cleanResponse
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        struct ModelResponse: Codable {
            let topic: String
            let summary: String
            let keyPoints: [String]
            let quizQuestions: [QuizQuestionData]
        }
        
        struct QuizQuestionData: Codable {
            let question: String
            let answer: String
        }
        
        guard let jsonData = cleanResponse.data(using: .utf8) else {
            throw NSError(domain: "StudyBuddy", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse model response"
            ])
        }
        
        let modelResponse = try JSONDecoder().decode(ModelResponse.self, from: jsonData)
        
        let quizQuestions = modelResponse.quizQuestions.map {
            QuizQuestion(question: $0.question, answer: $0.answer)
        }
        
        return StudySummary(
            duration: duration,
            summaryText: modelResponse.summary,
            keyPoints: modelResponse.keyPoints,
            quizQuestions: quizQuestions
        )
    }
}

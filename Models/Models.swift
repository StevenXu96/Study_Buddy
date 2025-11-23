import Foundation

// MARK: - Study Summary Model
struct StudySummary: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: String
    let summaryText: String
    let keyPoints: [String]
    let quizQuestions: [QuizQuestion]
    let transcriptPath: String?
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         duration: String,
         summaryText: String,
         keyPoints: [String],
         quizQuestions: [QuizQuestion],
         transcriptPath: String? = nil) {
        self.id = id
        self.date = date
        self.duration = duration
        self.summaryText = summaryText
        self.keyPoints = keyPoints
        self.quizQuestions = quizQuestions
        self.transcriptPath = transcriptPath
    }
    
    static var sample: StudySummary {
        StudySummary(
            duration: "2h 15m",
            summaryText: "This study session covered the fundamentals of quantum mechanics, including wave-particle duality, the uncertainty principle, and quantum entanglement. We explored how these concepts revolutionized our understanding of physics at the atomic and subatomic levels. Key experiments like the double-slit experiment were discussed in detail, demonstrating how observation affects quantum behavior.",
            keyPoints: [
                "Wave-particle duality shows that particles can exhibit both wave and particle properties",
                "Heisenberg's uncertainty principle states that we cannot simultaneously know both position and momentum with perfect precision",
                "Quantum entanglement demonstrates non-local correlations between particles",
                "The double-slit experiment reveals the strange nature of quantum measurement",
                "Schrödinger's equation describes the wave function evolution over time"
            ],
            quizQuestions: [
                QuizQuestion(
                    question: "What does wave-particle duality demonstrate?",
                    answer: "Wave-particle duality demonstrates that quantum entities can exhibit properties of both waves and particles depending on how they are measured or observed."
                ),
                QuizQuestion(
                    question: "Explain Heisenberg's uncertainty principle.",
                    answer: "The uncertainty principle states that there is a fundamental limit to the precision with which certain pairs of physical properties, such as position and momentum, can be known simultaneously."
                ),
                QuizQuestion(
                    question: "What is quantum entanglement?",
                    answer: "Quantum entanglement is a phenomenon where two or more particles become connected in such a way that the quantum state of one particle cannot be described independently of the others, even when separated by large distances."
                )
            ]
        )
    }
}

// MARK: - Quiz Question Model
struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let question: String
    let answer: String
    
    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}

// MARK: - Recording Session
struct RecordingSession {
    let startTime: Date
    var endTime: Date?
    let audioFileURL: URL
    
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - AI Response Models
struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

// MARK: - Transcription Result
struct TranscriptionResult {
    let text: String
    let duration: TimeInterval
    let wordCount: Int
    
    var isValid: Bool {
        return !text.isEmpty && wordCount > 10 // Minimum viable transcription
    }
}

// MARK: - Written Exam Models
class WrittenExamQuestion: Identifiable, ObservableObject {
    let id: UUID
    let question: String
    let context: String
    let modelAnswer: String
    @Published var score: Int
    @Published var feedback: String
    
    init(id: UUID = UUID(),
         question: String,
         context: String,
         modelAnswer: String,
         score: Int = 0,
         feedback: String = "") {
        self.id = id
        self.question = question
        self.context = context
        self.modelAnswer = modelAnswer
        self.score = score
        self.feedback = feedback
    }
}

struct QuestionEvaluation {
    let score: Int
    let feedback: String
}

struct QuestionEvaluations {
    let evaluations: [QuestionEvaluation]
    let overallFeedback: String
}

// MARK: - Oral Exam Models
struct OralExamQuestion {
    let question: String
    let context: String
    let modelAnswer: String
}

struct OralExamEvaluation {
    let score: Int
    let strengths: [String]
    let areasForImprovement: [String]
    let overallFeedback: String
}

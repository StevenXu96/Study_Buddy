import SwiftUI

struct WrittenExamView: View {
    let summary: StudySummary
    @StateObject private var viewModel: WrittenExamViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(summary: StudySummary) {
        self.summary = summary
        _viewModel = StateObject(wrappedValue: WrittenExamViewModel(summary: summary))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Written Exam")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text("Royal College Style Questions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Answer all questions based on the study session material")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Loading State
                    if viewModel.isGenerating {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Generating Royal College exam questions...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    }
                    
                    // Error State
                    else if let error = viewModel.errorMessage {
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Failed to generate questions")
                                .font(.headline)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                Task {
                                    await viewModel.generateQuestions()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    }
                    
                    // Questions
                    else if !viewModel.questions.isEmpty {
                        if viewModel.isSubmitted {
                            // Results View
                            ForEach(Array(viewModel.questions.enumerated()), id: \.offset) { index, question in
                                WrittenQuestionResultCard(
                                    question: question,
                                    userAnswer: viewModel.userAnswers[index],
                                    number: index + 1
                                )
                            }
                            
                            // Score Summary
                            VStack(spacing: 15) {
                                Divider()
                                
                                HStack {
                                    Text("Overall Feedback")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Text("\(viewModel.calculateScore())%")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(viewModel.calculateScore() >= 70 ? .green : .orange)
                                }
                                
                                Text(viewModel.overallFeedback)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            
                            Button("Close") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top)
                        } else {
                            // Question Input View
                            Text("Loaded \(viewModel.questions.count) questions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(viewModel.questions.enumerated()), id: \.offset) { index, question in
                                WrittenQuestionInputCard(
                                    question: question,
                                    answer: $viewModel.userAnswers[index],
                                    number: index + 1
                                )
                            }
                            
                            // Submit Button
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    Task {
                                        await viewModel.submitAnswers()
                                    }
                                }) {
                                    HStack {
                                        if viewModel.isEvaluating {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .padding(.trailing, 5)
                                        }
                                        
                                        Text(viewModel.isEvaluating ? "Evaluating..." : "Submit Answers")
                                    }
                                    .frame(width: 200)
                                    .padding()
                                    .background(viewModel.canSubmit ? Color.blue : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(!viewModel.canSubmit || viewModel.isEvaluating)
                                
                                Spacer()
                            }
                            .padding(.top)
                        }
                    }
                    // Debug: No questions state
                    else {
                        VStack(spacing: 15) {
                            Text("No questions loaded")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Debug: isGenerating=\(viewModel.isGenerating), hasError=\(viewModel.errorMessage != nil), questionCount=\(viewModel.questions.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    }
                }
                .padding(30)
            }
            .navigationTitle("Written Exam")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 900, height: 700)
        .onAppear {
            if viewModel.questions.isEmpty {
                Task {
                    await viewModel.generateQuestions()
                }
            }
        }
    }
}

struct WrittenQuestionInputCard: View {
    let question: WrittenExamQuestion
    @Binding var answer: String
    let number: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Question Header
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Text("\(number)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Text("Question \(number)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Divider()
            
            // Question Text
            Text(question.question)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Clinical Context
            if !question.context.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.blue)
                        Text("Clinical Context")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Text(question.context)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(10)
                }
            }
            
            Divider()
            
            // Answer Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.green)
                    Text("Your Answer")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("Provide a comprehensive answer (3-5 sentences recommended)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $answer)
                    .font(.body)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(answer.isEmpty ? Color.gray.opacity(0.3) : Color.blue.opacity(0.5), lineWidth: 2)
                    )
                
                HStack {
                    Text("\(answer.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if answer.split(separator: " ").count > 0 {
                        Text("\(answer.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(25)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct WrittenQuestionResultCard: View {
    let question: WrittenExamQuestion
    let userAnswer: String
    let number: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                Text("Question \(number)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: question.score >= 70 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text("\(question.score)%")
                }
                .font(.headline)
                .foregroundColor(question.score >= 70 ? .green : .orange)
            }
            
            Text(question.question)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.black)
            
            if !question.context.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Clinical Context:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Text(question.context)
                        .font(.caption)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                        .foregroundColor(.black)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Answer:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text(userAnswer.isEmpty ? "No answer provided" : userAnswer)
                    .font(.body)
                    .foregroundColor(userAnswer.isEmpty ? .secondary : .black)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Royal College Approved Answer:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(question.modelAnswer)
                    .font(.body)
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            }
            
            if !question.feedback.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Feedback:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text(question.feedback)
                        .font(.body)
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

import SwiftUI

struct OralExamView: View {
    let summary: StudySummary
    @StateObject private var viewModel: OralExamViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(summary: StudySummary) {
        self.summary = summary
        _viewModel = StateObject(wrappedValue: OralExamViewModel(summary: summary))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Oral Exam")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text("Royal College Style Oral Examination")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Answer the question verbally as you would in the actual exam")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Loading State
                    if viewModel.isGeneratingQuestion {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Generating oral exam question...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 50)
                    }
                    
                    // Error State
                    else if let error = viewModel.errorMessage {
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Failed to generate question")
                                .font(.headline)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Try Again") {
                                Task {
                                    await viewModel.generateQuestion()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 50)
                    }
                    
                    // Question Display
                    else if let question = viewModel.oralQuestion {
                        VStack(spacing: 20) {
                            // Question Card
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Examiner's Question")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                
                                Text(question.question)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if !question.context.isEmpty {
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Clinical Scenario:")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        Text(question.context)
                                            .font(.body)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(25)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(15)
                            
                            // Recording Status
                            if viewModel.isRecording {
                                VStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.2))
                                            .frame(width: 100, height: 100)
                                        
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 70, height: 70)
                                            .scaleEffect(viewModel.pulseAnimation ? 1.0 : 0.9)
                                            .animation(.easeInOut(duration: 1).repeatForever(), value: viewModel.pulseAnimation)
                                    }
                                    
                                    Text("Recording Your Answer")
                                        .font(.headline)
                                    
                                    Text(viewModel.recordingDuration)
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                    
                                    Text("Speak naturally and comprehensively...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        viewModel.stopRecording()
                                    }) {
                                        HStack {
                                            Image(systemName: "stop.fill")
                                            Text("Stop Recording")
                                        }
                                        .frame(width: 200)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.vertical, 20)
                            }
                            
                            // Processing Status
                            else if viewModel.isProcessing {
                                VStack(spacing: 15) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    
                                    Text(viewModel.processingStatus)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 50)
                            }
                            
                            // Results
                            else if viewModel.isEvaluated {
                                OralExamResultView(
                                    question: question,
                                    transcription: viewModel.answerTranscription,
                                    evaluation: viewModel.evaluation!
                                )
                                
                                Button("Close") {
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top)
                            }
                            
                            // Ready to Answer
                            else {
                                VStack(spacing: 20) {
                                    Image(systemName: "mic.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.blue)
                                    
                                    Text("Ready to record your answer?")
                                        .font(.headline)
                                    
                                    Text("You'll have unlimited time to provide your answer")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button(action: {
                                        viewModel.startRecording()
                                    }) {
                                        HStack {
                                            Image(systemName: "mic.fill")
                                            Text("Ready to Answer")
                                        }
                                        .frame(width: 220)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.vertical, 30)
                            }
                        }
                    }
                }
                .padding(30)
            }
            .navigationTitle("Oral Exam")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        }
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 800, height: 700)
        .onAppear {
            if viewModel.oralQuestion == nil {
                Task {
                    await viewModel.generateQuestion()
                }
            }
            viewModel.requestMicrophonePermission()
        }
    }
}

struct OralExamResultView: View {
    let question: OralExamQuestion
    let transcription: String
    let evaluation: OralExamEvaluation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Score Header
            HStack {
                Text("Evaluation Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: evaluation.score >= 70 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text("\(evaluation.score)%")
                }
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(evaluation.score >= 70 ? .green : .orange)
            }
            
            Divider()
            
            // Your Answer Transcription
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Answer (Transcribed):")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                ScrollView {
                    Text(transcription.isEmpty ? "No transcription available" : transcription)
                        .font(.body)
                        .foregroundColor(transcription.isEmpty ? .secondary : .black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
            }
            
            Divider()
            
            // Model Answer
            VStack(alignment: .leading, spacing: 10) {
                Text("Royal College Approved Answer:")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text(question.modelAnswer.isEmpty ? "Model answer not available" : question.modelAnswer)
                    .font(.body)
                    .foregroundColor(question.modelAnswer.isEmpty ? .secondary : .black)
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(10)
            }
            
            Divider()
            
            // Strengths
            if !evaluation.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Strengths:")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    
                    ForEach(evaluation.strengths, id: \.self) { strength in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.black)
                            Text(strength)
                                .foregroundColor(.black)
                        }
                        .font(.body)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.15))
                .cornerRadius(10)
            }
            
            // Areas for Improvement
            if !evaluation.areasForImprovement.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Areas for Improvement:")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    
                    ForEach(evaluation.areasForImprovement, id: \.self) { area in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.black)
                            Text(area)
                                .foregroundColor(.black)
                        }
                        .font(.body)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                .cornerRadius(10)
            }
            
            // Overall Feedback
            VStack(alignment: .leading, spacing: 10) {
                Text("Overall Feedback:")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text(evaluation.overallFeedback.isEmpty ? "No feedback available" : evaluation.overallFeedback)
                    .font(.body)
                    .foregroundColor(evaluation.overallFeedback.isEmpty ? .secondary : .black)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

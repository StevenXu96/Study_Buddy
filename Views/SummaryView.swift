import SwiftUI

struct SummaryView: View {
    let summary: StudySummary
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Study Session Summary")
                            .font(.system(size: 32, weight: .bold))
                        
                        HStack {
                            Label(summary.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                            Spacer()
                            Label(summary.duration, systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Main Summary
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(summary.summaryText)
                            .font(.body)
                            .lineSpacing(6)
                    }
                    
                    Divider()
                    
                    // Key Points
                    if !summary.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Key Points")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(Array(summary.keyPoints.enumerated()), id: \.offset) { index, point in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    
                                    Text(point)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Quiz Questions
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Quiz Questions")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(Array(summary.quizQuestions.enumerated()), id: \.offset) { index, question in
                            QuizQuestionCard(question: question, number: index + 1)
                        }
                    }
                }
                .padding(30)
            }
            .navigationTitle("Session Results")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 800, height: 700)
        .sheet(isPresented: $showingExportOptions) {
            ExportView(summary: summary)
        }
    }
}

struct QuizQuestionCard: View {
    let question: QuizQuestion
    let number: Int
    @State private var showAnswer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Q\(number):")
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text(question.question)
                    .fontWeight(.medium)
            }
            
            if showAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Answer:")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text(question.answer)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
                .transition(.opacity)
            }
            
            Button(action: {
                withAnimation {
                    showAnswer.toggle()
                }
            }) {
                Text(showAnswer ? "Hide Answer" : "Show Answer")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ExportView: View {
    let summary: StudySummary
    @Environment(\.dismiss) private var dismiss
    @State private var exportStatus = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Summary")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Choose export format")
                .foregroundColor(.secondary)
            
            VStack(spacing: 15) {
                Button(action: {
                    exportAsPDF()
                }) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Export as PDF")
                    }
                    .frame(width: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    exportAsMarkdown()
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Export as Markdown")
                    }
                    .frame(width: 200)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    copyToClipboard()
                }) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Copy to Clipboard")
                    }
                    .frame(width: 200)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            if !exportStatus.isEmpty {
                Text(exportStatus)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding()
            }
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.top)
        }
        .padding(40)
        .frame(width: 400, height: 400)
    }
    
    private func exportAsPDF() {
        let exporter = SummaryExporter()
        if let url = exporter.exportToPDF(summary: summary) {
            NSWorkspace.shared.open(url)
            exportStatus = "PDF exported successfully!"
        } else {
            exportStatus = "Export failed"
        }
    }
    
    private func exportAsMarkdown() {
        let exporter = SummaryExporter()
        if let url = exporter.exportToMarkdown(summary: summary) {
            NSWorkspace.shared.open(url)
            exportStatus = "Markdown exported successfully!"
        } else {
            exportStatus = "Export failed"
        }
    }
    
    private func copyToClipboard() {
        let exporter = SummaryExporter()
        let text = exporter.generateMarkdownText(summary: summary)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        exportStatus = "Copied to clipboard!"
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView(summary: StudySummary.sample)
    }
}

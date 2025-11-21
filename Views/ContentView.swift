import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Study Buddy")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.blue)
            
            Text("Record your study session and get AI-powered summaries & quizzes")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Recording Status
            if viewModel.isRecording {
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 80, height: 80)
                            .scaleEffect(viewModel.pulseAnimation ? 1.0 : 0.9)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: viewModel.pulseAnimation)
                    }
                    
                    Text("Recording in Progress")
                        .font(.headline)
                    
                    Text(viewModel.recordingDuration)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text("Keep speaking naturally...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Ready to Record")
                        .font(.headline)
                    
                    Text("Press Start to begin your study session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Processing Status
            if viewModel.isProcessing {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text(viewModel.processingStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                if viewModel.isRecording {
                    Button(action: {
                        viewModel.stopRecording()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop & Process")
                        }
                        .frame(width: 180)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    Button(action: {
                        viewModel.startRecording()
                    }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Start Recording")
                        }
                        .frame(width: 180)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isProcessing)
                }
                
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 30)
        }
        .frame(width: 600, height: 500)
        .padding()
        .sheet(isPresented: $viewModel.showingSummary) {
            if let summary = viewModel.generatedSummary {
                SummaryView(summary: summary)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            viewModel.requestMicrophonePermission()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

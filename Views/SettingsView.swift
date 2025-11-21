import SwiftUI

struct SettingsView: View {
    @AppStorage("transcriptionMode") private var transcriptionMode = "local"
    @AppStorage("processingMode") private var processingMode = ProcessingMode.builtin.rawValue
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("modelSelection") private var modelSelection = "gpt-4"
    @AppStorage("ollamaModel") private var ollamaModel = "phi3"
    @AppStorage("ollamaURL") private var ollamaURL = "http://localhost:11434"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Divider()
            
            // Transcription Mode
            VStack(alignment: .leading, spacing: 10) {
                Text("Audio Transcription")
                    .font(.headline)
                
                Picker("Transcription Method", selection: $transcriptionMode) {
                    Text("Apple Speech (Free, Private)").tag("local")
                    Text("OpenAI Whisper (Best Accuracy)").tag("whisper")
                }
                .pickerStyle(.radioGroup)
                
                if transcriptionMode == "local" {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("100% on-device - audio never leaves your Mac")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        Text("Best for medical/technical terms - audio sent to OpenAI")
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Processing Mode for Summary Generation
            VStack(alignment: .leading, spacing: 10) {
                Text("Summary & Quiz Generation")
                    .font(.headline)
                
                Picker("Mode", selection: $processingMode) {
                    Text("Built-in (Fast & Private)").tag(ProcessingMode.builtin.rawValue)
                    Text("Ollama (Local AI)").tag(ProcessingMode.ollama.rawValue)
                    Text("OpenAI API (Cloud)").tag(ProcessingMode.cloud.rawValue)
                }
                .pickerStyle(.radioGroup)
                
                Text("Choose how to generate summaries and quiz questions from your transcript.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Ollama Settings
            if ProcessingMode(rawValue: processingMode) == .ollama {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ollama Configuration")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text("Ollama runs locally on your Mac")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Text("Server URL:")
                            .frame(width: 100, alignment: .leading)
                        TextField("http://localhost:11434", text: $ollamaURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Model:")
                            .frame(width: 100, alignment: .leading)
                        TextField("llama3.2", text: $ollamaModel)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Don't have Ollama?")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Link("1. Download Ollama", destination: URL(string: "https://ollama.com/download")!)
                            .font(.caption)
                        
                        Text("2. Run in Terminal: ollama pull llama3.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("3. Ollama will start automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 5)
                }
                
                Divider()
            }
            
            // OpenAI Settings
            if ProcessingMode(rawValue: processingMode) == .cloud {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OpenAI Configuration")
                        .font(.headline)
                    
                    SecureField("API Key", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Your API key is stored securely and only used for summary generation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Model", selection: $modelSelection) {
                        Text("GPT-4 (Best Quality)").tag("gpt-4")
                        Text("GPT-4 Turbo").tag("gpt-4-turbo-preview")
                        Text("GPT-3.5 Turbo (Faster)").tag("gpt-3.5-turbo")
                    }
                    .pickerStyle(.menu)
                }
                
                Divider()
            }
            
            // About
            VStack(alignment: .leading, spacing: 5) {
                Text("About")
                    .font(.headline)
                
                Text("Study Buddy v1.0")
                    .font(.caption)
                
                Text("Record study sessions and generate AI-powered summaries and quizzes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 550, height: 650)
    }
}

enum ProcessingMode: String {
    case builtin = "builtin"
    case ollama = "ollama"
    case cloud = "cloud"
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

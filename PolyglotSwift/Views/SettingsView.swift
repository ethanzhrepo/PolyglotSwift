import SwiftUI

struct SettingsView: View {
    @AppStorage("deepl_api_key") private var apiKey: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("DeepL Settings")) {
                TextField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 300)
                
                Text("Get your API key from DeepL Developer Portal")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Spacer()
                Button("Close") {
                    if let window = NSApplication.shared.keyWindow {
                        window.close()
                    }
                }
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 200)
    }
} 
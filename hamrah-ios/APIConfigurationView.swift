import SwiftUI

struct APIConfigurationView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var configuration = APIConfiguration.shared
    @State private var customURLText: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Environment")) {
                    ForEach(APIConfiguration.Environment.allCases, id: \.self) { environment in
                        HStack {
                            Text(environment.rawValue)
                            Spacer()
                            if configuration.currentEnvironment == environment {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            configuration.currentEnvironment = environment
                            if environment != .custom {
                                customURLText = ""
                            }
                        }
                    }
                }
                
                if configuration.currentEnvironment == .custom {
                    Section(header: Text("Custom API URL"), 
                           footer: Text("Enter your custom API endpoint. HTTPS will be enforced automatically.")) {
                        TextField("api.example.com", text: $customURLText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                updateCustomURL()
                            }
                        
                        Button("Update Custom URL") {
                            updateCustomURL()
                        }
                        .disabled(customURLText.isEmpty)
                    }
                }
                
                Section(header: Text("Current Configuration")) {
                    HStack {
                        Text("Base URL")
                        Spacer()
                        Text(configuration.baseURL)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(configuration.currentEnvironment.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Reset to Production") {
                        configuration.reset()
                        customURLText = ""
                        showSuccessAlert("Configuration reset to production")
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("API Configuration")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                customURLText = configuration.customBaseURL
            }
            .alert("Configuration", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func updateCustomURL() {
        guard !customURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showErrorAlert("Please enter a valid URL")
            return
        }
        
        configuration.setCustomURL(customURLText.trimmingCharacters(in: .whitespacesAndNewlines))
        showSuccessAlert("Custom URL updated successfully")
    }
    
    private func showSuccessAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func showErrorAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    APIConfigurationView()
}
import SwiftUI

struct APIConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = APIConfiguration.shared
    @State private var customApiURLText: String = ""
    @State private var customWebURLText: String = ""
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
                                customApiURLText = ""
                                customWebURLText = ""
                            }
                        }
                    }
                }

                if configuration.currentEnvironment == .custom {
                    Section(
                        header: Text("Custom URLs"),
                        footer: Text(
                            "Set separate endpoints for API and WebAuthn operations. API may use http or https in development. Web App URL will use HTTPS."
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Base URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField(
                                "http://127.0.0.1:8787 or https://api.example.com",
                                text: $customApiURLText
                            )
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            #endif
                            .onSubmit {
                                updateCustomURLs()
                            }

                            Text("Web App URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField(
                                "https://localhost:5173 or https://hamrah.app",
                                text: $customWebURLText
                            )
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            #endif
                            .onSubmit {
                                updateCustomURLs()
                            }

                            Button("Update Custom URLs") {
                                updateCustomURLs()
                            }
                            .disabled(customApiURLText.isEmpty || customWebURLText.isEmpty)
                        }
                    }
                }

                Section(header: Text("Current Configuration")) {
                    HStack {
                        Text("API Base URL")
                        Spacer()
                        Text(configuration.baseURL)
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .lineLimit(2)
                    }

                    HStack {
                        Text("Web App URL")
                        Spacer()
                        Text(configuration.webAppBaseURL)
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .lineLimit(2)
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
                        customApiURLText = ""
                        customWebURLText = ""
                        showSuccessAlert("Configuration reset to production")
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("API Configuration")
            #if os(iOS)
                .navigationBarItems(
                    trailing: Button("Done") {
                        dismiss()
                    }
                )
            #else
                .formStyle(.grouped)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button("Apply") {
                            updateCustomURLs()
                        }
                        .disabled(
                            configuration.currentEnvironment == .custom
                                && (customApiURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty
                                    || customWebURLText.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ).isEmpty)
                        )
                    }
                }
                .frame(minWidth: 520, minHeight: 520)
            #endif
            .onAppear {
                customApiURLText = configuration.customApiBaseURL
                customWebURLText = configuration.customWebAppBaseURL
            }
            .alert("Configuration", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func updateCustomURLs() {
        let api = customApiURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let web = customWebURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !api.isEmpty, !web.isEmpty else {
            showErrorAlert("Please enter both API and Web App URLs")
            return
        }

        configuration.setCustomApiURL(api)
        configuration.setCustomWebURL(web)
        showSuccessAlert("Custom URLs updated successfully")
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

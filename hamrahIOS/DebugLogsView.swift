//
//  DebugLogsView.swift
//  hamrahIOS
//
//  Debug logs viewer for troubleshooting
//

import SwiftUI

struct DebugLogsView: View {
    @State private var logContent = ""
    @State private var isLoading = true
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading logs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if logContent.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No debug logs found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Debug logs will appear here when authentication events occur")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(logContent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: loadLogs) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showShareSheet = true }) {
                            Label("Share Logs", systemImage: "square.and.arrow.up")
                        }
                        .disabled(logContent.isEmpty)
                        
                        Button(action: clearLogs) {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        .disabled(logContent.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        // Dismiss view - implement based on how you present this view
                    }
                }
            }
            .onAppear {
                loadLogs()
            }
            .sheet(isPresented: $showShareSheet) {
                if let logFileURL = DebugLogger.shared.getLogFileURL() {
                    ShareSheet(items: [logFileURL])
                }
            }
        }
    }
    
    private func loadLogs() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let content: String
            
            if let logFileURL = DebugLogger.shared.getLogFileURL(),
               let data = try? Data(contentsOf: logFileURL),
               let logText = String(data: data, encoding: .utf8) {
                content = logText
            } else {
                content = ""
            }
            
            DispatchQueue.main.async {
                self.logContent = content
                self.isLoading = false
            }
        }
    }
    
    private func clearLogs() {
        DebugLogger.shared.clearLogs()
        logContent = ""
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DebugLogsView()
}
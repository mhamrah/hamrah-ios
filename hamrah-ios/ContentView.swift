//
//  ContentView.swift
//  hamrahIOS
//
//  Created by Mike Hamrah on 8/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @EnvironmentObject var authManager: NativeAuthManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @State private var showBiometricSetupPrompt = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: MyAccountView().environmentObject(authManager).environmentObject(biometricManager)) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .onAppear {
            checkBiometricSetupPrompt()
        }
        .sheet(isPresented: $showBiometricSetupPrompt) {
            BiometricSetupPromptView(
                onSetup: {
                    showBiometricSetupPrompt = false
                },
                onSkip: {
                    showBiometricSetupPrompt = false
                    // Mark that user was prompted so we don't ask again
                    UserDefaults.standard.set(true, forKey: "hamrah_biometric_setup_prompted")
                }
            )
            .environmentObject(biometricManager)
        }
    }
    
    private func checkBiometricSetupPrompt() {
        // Only show prompt if:
        // 1. Biometric auth is available
        // 2. User hasn't enabled it yet
        // 3. User hasn't been prompted before
        let hasBeenPrompted = UserDefaults.standard.bool(forKey: "hamrah_biometric_setup_prompted")
        
        if biometricManager.isAvailable && 
           !biometricManager.isBiometricEnabled && 
           !hasBeenPrompted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showBiometricSetupPrompt = true
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .environmentObject(NativeAuthManager())
        .environmentObject(BiometricAuthManager())
}

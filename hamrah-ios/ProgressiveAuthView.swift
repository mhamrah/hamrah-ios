//
//  ProgressiveAuthView.swift
//  hamrahIOS
//
//  Simple authentication view that shows login or content based on auth state
//

import SwiftUI

struct ProgressiveAuthView: View {
    @EnvironmentObject private var authManager: NativeAuthManager
    @EnvironmentObject private var biometricManager: BiometricAuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(biometricManager)
            } else {
                NativeLoginView()
                    .environmentObject(authManager)
                    .environmentObject(biometricManager)
            }
        }
    }
}

#Preview {
    ProgressiveAuthView()
        .environmentObject(NativeAuthManager())
        .environmentObject(BiometricAuthManager())
}
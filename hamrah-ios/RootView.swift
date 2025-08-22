//
//  RootView.swift
//  hamrahIOS
//
//  Root view that handles progressive authentication flow
//

import SwiftUI

struct RootView: View {
    @StateObject private var nativeAuthManager = NativeAuthManager()
    @StateObject private var biometricManager = BiometricAuthManager()
    
    var body: some View {
        ProgressiveAuthView(
            authManager: nativeAuthManager,
            biometricManager: biometricManager
        )
        .environmentObject(nativeAuthManager)
        .environmentObject(biometricManager)
    }
}

#Preview {
    RootView()
}
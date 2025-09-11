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
    @EnvironmentObject private var urlManager: URLManager
    
    var body: some View {
        ProgressiveAuthView()
            .environmentObject(nativeAuthManager)
            .environmentObject(biometricManager)
            .environmentObject(urlManager)
    }
}

#Preview {
    RootView()
}
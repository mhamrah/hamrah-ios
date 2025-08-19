//
//  RootView.swift
//  hamrahIOS
//
//  Root view that handles authentication state and navigation
//

import SwiftUI

struct RootView: View {
    @StateObject private var nativeAuthManager = NativeAuthManager()
    
    var body: some View {
        Group {
            if nativeAuthManager.isAuthenticated {
                ContentView()
                    .environmentObject(nativeAuthManager)
            } else {
                NativeLoginView()
                    .environmentObject(nativeAuthManager)
            }
        }
    }
}

#Preview {
    RootView()
}
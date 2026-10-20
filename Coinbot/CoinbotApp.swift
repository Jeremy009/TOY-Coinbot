//
//  CoinbotApp.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 07/08/2025.
//

import SwiftUI

@main
struct CoinbotApp: App {
    @StateObject private var authManager: AuthenticationManager

    init() {
        let authManager = AuthenticationManager()
        if DemoMode.isEnabled {
            DemoMode.activate(authManager: authManager)
        }
        _authManager = StateObject(wrappedValue: authManager)
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(authManager)
        }
    }
}

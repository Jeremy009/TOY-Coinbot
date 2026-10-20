//
//  ContentView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 07/08/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = DemoMode.isEnabled ? DemoMode.initialTab : "assets"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Assets Tab
            AssetsView()
                .tabItem {
                    Image(systemName: "bitcoinsign.circle.fill")
                    Text("Assets")
                }
                .tag("assets")
                .environmentObject(authManager)
            
            // Orders Tab
            OrdersView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text("Orders")
                }
                .tag("orders")
                .environmentObject(authManager)
            
            // Bots Tab
            BotsView()
                .tabItem {
                    Image(systemName: "cpu.fill")
                    Text("Bots")
                }
                .tag("bots")
                .environmentObject(authManager)
            
            // Performance Tab
            PerformanceView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Performance")
                }
                .tag("performance")
                .environmentObject(authManager)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag("settings")
                .environmentObject(authManager)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}

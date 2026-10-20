//
//  BotsView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 12/08/2025.
//

import SwiftUI

struct BotsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var statusText = "Ready"
    
    var body: some View {
        NavigationStack {
            BotsViewContent()
                .environmentObject(authManager)
                .navigationTitle("Bots")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            statusText = "Refreshing..."
                            // TODO: Implement refresh functionality
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                }
        }
    }
}

struct BotsViewContent: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "cpu")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Bots")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Trading bot management functionality coming soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    BotsView()
        .environmentObject(AuthenticationManager())
}
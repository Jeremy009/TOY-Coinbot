//
//  PerformanceView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 12/08/2025.
//

import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var statusText = "Ready"
    
    var body: some View {
        NavigationStack {
            PerformanceViewContent()
                .environmentObject(authManager)
                .navigationTitle("Performance")
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

struct PerformanceViewContent: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Performance")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Portfolio performance analytics coming soon")
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
    PerformanceView()
        .environmentObject(AuthenticationManager())
}
import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingAPIKeyForm = false
    @State private var showingPasscodeReset = false
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    
    
    var body: some View {
        NavigationStack {
            SettingsViewContent()
                .environmentObject(authManager)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsViewContent: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingAPIKeyForm = false
    @State private var showingPasscodeReset = false
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    
    private func biometricCapabilityAvailable() -> Bool {
        return authManager.isBiometricAuthenticationAvailable()
    }
    
    var body: some View {
        List {
                // Security Section
                Section("Security") {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.blue)
                        Text("Face ID")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { authManager.isFaceIDEnabled },
                            set: { authManager.toggleFaceID($0) }
                        ))
                        .labelsHidden()
                    }
                    .disabled(!biometricCapabilityAvailable())
                    
                    Button(action: {
                        showingPasscodeReset = true
                    }) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.orange)
                            Text("Change Passcode")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    
                }
                
                // API Configuration Section
                Section("Trading Configuration") {
                    HStack {
                        Image(systemName: authManager.hasAPIKey ? "checkmark.shield" : "exclamationmark.shield")
                            .foregroundColor(authManager.hasAPIKey ? .green : .red)
                        Text("Bitvavo API Keys")
                        Spacer()
                        Text(authManager.hasAPIKey ? "Configured" : "Not Set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        loadExistingAPIKeys()
                        showingAPIKeyForm = true
                    }) {
                        HStack {
                            Image(systemName: "key.radiowaves.forward")
                                .foregroundColor(.blue)
                            Text(authManager.hasAPIKey ? "Update API Keys" : "Enter API Keys")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    if authManager.hasAPIKey {
                        Button(action: {
                            Task {
                                await testConnection()
                            }
                        }) {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wifi")
                                        .foregroundColor(.green)
                                }
                                Text("Test Connection")
                                Spacer()
                                if let result = connectionTestResult {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(result == "Success" ? .green : .red)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .disabled(isTestingConnection)
                        
                        Button(action: {
                            authManager.deleteAPICredentials()
                            connectionTestResult = nil
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Delete API Keys")
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                
                
                // App Information Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text(AppConstants.appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "bitcoinsign.circle")
                            .foregroundColor(.orange)
                        Text("Exchange")
                        Spacer()
                        Text("Bitvavo")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingAPIKeyForm) {
                APIKeyFormView(
                    authManager: authManager,
                    apiKey: $apiKey,
                    apiSecret: $apiSecret
                )
            }
            .alert("Reset Passcode", isPresented: $showingPasscodeReset) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    authManager.resetPasscode()
                }
            } message: {
                Text("This will delete your current passcode and require you to set up a new one. Are you sure?")
            }
    }
    
    private func loadExistingAPIKeys() {
        if let credentials = SecureCredentialManager.loadCredentials() {
            credentials.withApiKey { key in
                credentials.withApiSecret { secret in
                    apiKey = key
                    apiSecret = secret
                }
            }
        } else {
            apiKey = ""
            apiSecret = ""
        }
    }
    
    private func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        
        let success = await authManager.testAPIConnection()
        
        await MainActor.run {
            isTestingConnection = false
            connectionTestResult = success ? "Success" : "Failed"
        }
    }
}

struct APIKeyFormView: View {
    let authManager: AuthenticationManager
    @Binding var apiKey: String
    @Binding var apiSecret: String
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your Bitvavo API credentials")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("These will be stored securely in your device's Keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("API Configuration")
                }
                
                Section("Credentials") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter API Secret", text: $apiSecret)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    }
                }
                
                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveCredentials()
                    }
                    .disabled(apiKey.isEmpty || apiSecret.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveCredentials() {
        isSaving = true
        saveError = nil
        
        // Clear credentials from memory after use
        defer {
            apiKey = ""
            apiSecret = ""
            isSaving = false
        }
        
        if SecureCredentialManager.saveCredentials(apiKey: apiKey, apiSecret: apiSecret) {
            dismiss()
        } else {
            saveError = "Failed to save API credentials securely"
        }
    }
}

struct PasscodeResetView: View {
    let authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Reset Passcode")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("This will remove your current passcode and require you to set up a new one. You will be logged out of the app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button("Reset Passcode") {
                    showingConfirmation = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Reset Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Reset Passcode", isPresented: $showingConfirmation) {
            Button("Reset", role: .destructive) {
                authManager.resetPasscode()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to reset your passcode? This action cannot be undone.")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager())
}
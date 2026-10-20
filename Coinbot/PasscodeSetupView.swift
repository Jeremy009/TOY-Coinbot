import SwiftUI

struct PasscodeSetupView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var setupStep: SetupStep = .enterPasscode
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum SetupStep {
        case enterPasscode
        case confirmPasscode
        case completed
    }
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: UIConstants.IconSize.large))
                    .foregroundColor(.blue)
                
                Text(NSLocalizedString("secure_your_app", comment: "Secure app title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(setupStep == .enterPasscode ? 
                     NSLocalizedString("create_passcode", comment: "Create passcode instruction") : 
                     NSLocalizedString("confirm_passcode", comment: "Confirm passcode instruction"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                PasscodeDotsView(
                    passcode: setupStep == .enterPasscode ? passcode : confirmPasscode,
                    maxDigits: 4
                )
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            NumericKeypadView(
                onDigitPressed: handleDigitEntry,
                onDelete: handleDelete
            )
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func handleDigitEntry(_ digit: String) {
        let currentPasscode = setupStep == .enterPasscode ? passcode : confirmPasscode
        
        guard currentPasscode.count < SecurityConstants.passcodeLength else { return }
        
        if setupStep == .enterPasscode {
            passcode += digit
            if passcode.count == SecurityConstants.passcodeLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Animation.standard) {
                    setupStep = .confirmPasscode
                    showError = false
                }
            }
        } else {
            confirmPasscode += digit
            if confirmPasscode.count == SecurityConstants.passcodeLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Animation.standard) {
                    validateAndSavePasscode()
                }
            }
        }
    }
    
    private func handleDelete() {
        if setupStep == .enterPasscode {
            if !passcode.isEmpty {
                passcode.removeLast()
            }
        } else {
            if !confirmPasscode.isEmpty {
                confirmPasscode.removeLast()
            } else {
                setupStep = .enterPasscode
                passcode = ""
                showError = false
            }
        }
    }
    
    private func validateAndSavePasscode() {
        if passcode == confirmPasscode {
            if authManager.setupPasscode(passcode) {
                setupStep = .completed
                authManager.isAuthenticated = true
            } else {
                showError(message: "Failed to save passcode")
            }
        } else {
            showError(message: "Passcodes don't match")
            confirmPasscode = ""
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        confirmPasscode = ""
    }
}

struct PasscodeDotsView: View {
    let passcode: String
    let maxDigits: Int
    
    var body: some View {
        HStack(spacing: UIConstants.PasscodeDots.spacing) {
            ForEach(0..<maxDigits, id: \.self) { index in
                Circle()
                    .fill(index < passcode.count ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: UIConstants.PasscodeDots.size, height: UIConstants.PasscodeDots.size)
                    .scaleEffect(index < passcode.count ? UIConstants.PasscodeDots.activeScale : 1.0)
                    .animation(.easeInOut(duration: UIConstants.Animation.fast), value: passcode.count)
            }
        }
    }
}

struct NumericKeypadView: View {
    let onDigitPressed: (String) -> Void
    let onDelete: () -> Void
    let onFaceID: (() -> Void)?
    let biometricIcon: String
    
    private var keypadLayout: [[String]] {
        if onFaceID != nil {
            return [
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"],
                ["faceid", "0", "delete"]
            ]
        } else {
            return [
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"],
                ["", "0", "delete"]
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.small) {
            ForEach(keypadLayout, id: \.self) { row in
                HStack(spacing: UIConstants.Spacing.small) {
                    ForEach(row, id: \.self) { key in
                        KeypadButton(
                            key: key,
                            onDigitPressed: onDigitPressed,
                            onDelete: onDelete,
                            onFaceID: onFaceID,
                            biometricIcon: biometricIcon
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    init(onDigitPressed: @escaping (String) -> Void, onDelete: @escaping () -> Void, onFaceID: (() -> Void)? = nil, biometricIcon: String = "faceid") {
        self.onDigitPressed = onDigitPressed
        self.onDelete = onDelete
        self.onFaceID = onFaceID
        self.biometricIcon = biometricIcon
    }
}

struct KeypadButton: View {
    let key: String
    let onDigitPressed: (String) -> Void
    let onDelete: () -> Void
    let onFaceID: (() -> Void)?
    let biometricIcon: String
    
    var body: some View {
        Button(action: {
            if key == "delete" {
                onDelete()
            } else if key == "faceid" {
                onFaceID?()
            } else if !key.isEmpty {
                onDigitPressed(key)
            }
        }) {
            ZStack {
                if key == "delete" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                } else if key == "faceid" {
                    Image(systemName: biometricIcon)
                        .font(.title2)
                        .foregroundColor(.blue)
                } else if !key.isEmpty {
                    Text(key)
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: UIConstants.ButtonSize.keypadMinHeight)
            .background(
                key.isEmpty ? Color.clear : Color.gray.opacity(0.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(key.isEmpty && key != "faceid")
        .scaleEffect(key.isEmpty ? 0 : 1)
    }
    
    init(key: String, onDigitPressed: @escaping (String) -> Void, onDelete: @escaping () -> Void, onFaceID: (() -> Void)? = nil, biometricIcon: String = "faceid") {
        self.key = key
        self.onDigitPressed = onDigitPressed
        self.onDelete = onDelete
        self.onFaceID = onFaceID
        self.biometricIcon = biometricIcon
    }
}

#Preview {
    PasscodeSetupView(authManager: AuthenticationManager())
}
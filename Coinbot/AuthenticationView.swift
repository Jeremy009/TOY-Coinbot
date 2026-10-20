import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var enteredPasscode = ""
    @State private var showPasscodeEntry = false
    @State private var biometricType: LABiometryType = .none
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with title
                VStack(spacing: 16) {
                    Text(AppConstants.appName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 60)
                    
                    Text(NSLocalizedString("enter_passcode", comment: "Enter passcode instruction"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)
                
                // Passcode dots
                PasscodeDotsView(
                    passcode: enteredPasscode,
                    maxDigits: 4
                )
                .padding(.bottom, 20)
                
                Spacer()
                Spacer()
                
                // Keypad section with Face ID in lower left - positioned at bottom
                NumericKeypadView(
                    onDigitPressed: handlePasscodeEntry,
                    onDelete: handlePasscodeDelete,
                    onFaceID: (biometricType != .none && authManager.isFaceIDEnabled) ? {
                        authManager.authenticateWithBiometrics()
                    } : nil,
                    biometricIcon: biometricIcon
                )
                .padding(.bottom, 20)
                
                if let error = authManager.authenticationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            detectBiometricType()
            showPasscodeEntry = true
            if biometricType != .none && authManager.isFaceIDEnabled {
                authManager.authenticateWithBiometrics()
            }
        }
    }
    
    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return Icons.Authentication.faceID
        case .touchID:
            return Icons.Authentication.touchID
        default:
            return Icons.Authentication.lock
        }
    }
    
    private var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometrics"
        }
    }
    
    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }
    
    private func handlePasscodeEntry(_ digit: String) {
        guard enteredPasscode.count < SecurityConstants.passcodeLength else { return }
        
        enteredPasscode += digit
        
        if enteredPasscode.count == SecurityConstants.passcodeLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Animation.standard) {
                validatePasscode()
            }
        }
    }
    
    private func handlePasscodeDelete() {
        if !enteredPasscode.isEmpty {
            enteredPasscode.removeLast()
        }
    }
    
    private func validatePasscode() {
        if authManager.authenticateWithPasscode(enteredPasscode) {
            enteredPasscode = ""
            showPasscodeEntry = false
        } else {
            enteredPasscode = ""
        }
    }
}

#Preview {
    AuthenticationView(authManager: AuthenticationManager())
}
import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
            } else if authManager.hasSetupPasscode {
                AuthenticationView(authManager: authManager)
            } else {
                PasscodeSetupView(authManager: authManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.hasSetupPasscode)
    }
}

#Preview {
    MainAppView()
        .environmentObject(AuthenticationManager())
}
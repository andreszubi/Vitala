import SwiftUI

struct AuthRootView: View {
    @State private var path = NavigationPath()
    @State private var showSignUp = false

    var body: some View {
        NavigationStack(path: $path) {
            SignInView(onCreateAccount: { path.append(AuthDest.signUp) },
                       onForgotPassword: { path.append(AuthDest.forgot) })
                .navigationDestination(for: AuthDest.self) { dest in
                    switch dest {
                    case .signUp: SignUpView()
                    case .forgot: ForgotPasswordView()
                    }
                }
        }
    }
}

enum AuthDest: Hashable { case signUp, forgot }

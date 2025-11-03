import SwiftUI

struct AuthView: View {
    @StateObject var vm = AuthViewModel()
    @State private var modeIsSignup = true
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Wizzle").font(.largeTitle).bold()
            
            if modeIsSignup {
                TextField("First name", text: $vm.givenName)
                TextField("Last name", text: $vm.familyName)
            }
            TextField("Email", text: $vm.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            SecureField("Password", text: $vm.password)
            
            if vm.isLoading { ProgressView() }
            
            Button(modeIsSignup ? "Create account" : "Sign in") {
                Task { modeIsSignup ? await vm.signUp() : await vm.signIn()}
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)
            
            Button(modeIsSignup ? "Have an account? Sign in" : "New here? Create account") {
                modeIsSignup.toggle()
            }
            .padding(.top, 8)
            
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.footnote)
            }
        }
        .padding()
    }
}

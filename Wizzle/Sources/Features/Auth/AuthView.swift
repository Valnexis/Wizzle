import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var modeIsSignup = true
    @FocusState private var focusedField: Field?
    
    enum Field { case given, family, email, password }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                // MARK: - App Title
                VStack(spacing: 6) {
                    Text("Wizzle")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(modeIsSignup ? "Create your account" : "Welcome back")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 24)
                
                // MARK: - Input Fields
                Group {
                    if modeIsSignup {
                        TextField("First name", text: $vm.givenName)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .given)
                            .submitLabel(.next)
                        
                        TextField("Last name", text: $vm.familyName)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .family)
                            .submitLabel(.next)
                    }
                    
                    TextField("Email", text: $vm.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                    
                    SecureField("Password", text: $vm.password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                }
                .disableAutocorrection(true)
                
                // MARK: - Action Buttons
                if vm.isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(.circular)
                        .padding(.top)
                } else {
                    Button {
                        Task {
                            if modeIsSignup {
                                await vm.signUp()
                            } else {
                                await vm.signIn()
                            }
                        }
                    } label: {
                        Text(modeIsSignup ? "Create Account" : "Sign In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!formIsValid || vm.isLoading)
                    .padding(.top, 8)
                    .animation(.easeInOut, value: formIsValid)
                }
                
                // MARK: - Mode Toggle
                Button {
                    modeIsSignup.toggle()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        focusedField = nil
                    }
                } label: {
                    Text(modeIsSignup
                         ? "Already have an account? Sign In"
                         : "New here? Create Account")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                .padding(.top, 12)
                
                // MARK: - Error Message
                if let err = vm.error {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationBarHidden(true)
            .onSubmit {
                switch focusedField {
                case .given: focusedField = .family
                case .family: focusedField = .email
                case .email: focusedField = .password
                default:
                    Task {
                        modeIsSignup ? await vm.signUp() : await vm.signIn()
                    }
                }
            }
        }
    }
    
    // MARK: - Validation
    private var formIsValid: Bool {
        if modeIsSignup {
            return !vm.givenName.isEmpty &&
                   !vm.familyName.isEmpty &&
                   vm.email.contains("@") &&
                   vm.password.count >= 6
        } else {
            return vm.email.contains("@") &&
                   vm.password.count >= 6
        }
    }
}

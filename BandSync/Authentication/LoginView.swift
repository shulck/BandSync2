import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isRegisterPresented = false
    @State private var isPhoneAuthPresented = false
    @State private var rememberMe = true
    @State private var showBiometricButton = false
    @State private var isLoggingIn = false
    
    private let biometricManager = BiometricAuthManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок
            Text("BandSync")
                .font(.largeTitle)
                .bold()
                .padding(.top, 50)
            
            Text("Login")
                .font(.title)
                .bold()
                .padding(.bottom, 20)

            // Форма входа
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Toggle("Remember me", isOn: $rememberMe)
                    .padding(.horizontal)
            }
            
            // Сообщение об ошибке
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            // Кнопка входа
            Button(action: login) {
                if isLoggingIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLoggingIn ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            .disabled(isLoggingIn)
            
            // Биометрическая кнопка входа
            if showBiometricButton {
                Button(action: biometricLogin) {
                    HStack {
                        Image(systemName: biometricManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text("Sign in with \(biometricManager.biometricType == .faceID ? "Face ID" : "Touch ID")")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // Дополнительные опции
            VStack(spacing: 15) {
                Button(action: {
                    isRegisterPresented = true
                }) {
                    Text("Register")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    isPhoneAuthPresented = true
                }) {
                    Text("Sign in with Phone Number")
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isRegisterPresented) {
            RegisterView(isLoggedIn: $isLoggedIn)
        }
        .sheet(isPresented: $isPhoneAuthPresented) {
            PhoneAuthView(isLoggedIn: $isLoggedIn)
        }
        .onAppear {
            // Проверяем наличие сохраненных данных для входа
            checkSavedCredentials()
            
            // Проверяем доступность биометрии
            showBiometricButton = biometricManager.biometricType != .none
        }
    }

    func login() {
        // Сбрасываем сообщение об ошибке
        errorMessage = ""
        
        // Проверка на пустые поля
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            return
        }
        
        isLoggingIn = true
        
        // Вход через Firebase
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoggingIn = false
            
            if let error = error {
                // Более понятное сообщение об ошибке
                let errorCode = (error as NSError).code
                switch errorCode {
                case 17009: // Неверный пароль
                    errorMessage = "Incorrect password, please try again"
                case 17011: // Account doesn't exist
                    errorMessage = "Account not found. Please check your email or register"
                case 17010: // Network error
                    errorMessage = "Network error. Please check your connection"
                default:
                    errorMessage = "Login error: \(error.localizedDescription)"
                }
            } else if let user = result?.user {
                // Сохраняем данные для последующего автоматического входа
                if rememberMe {
                    if biometricManager.biometricType != .none {
                        // Если доступна биометрия, предлагаем её включить
                        saveBiometricCredentials(user: user)
                    } else {
                        // Иначе просто сохраняем email
                        UserDefaults.standard.set(email, forKey: "savedEmail")
                    }
                }
                isLoggedIn = true
            }
        }
    }
    
    func biometricLogin() {
        BiometricAuthManager.shared.authenticate { result in
            switch result {
            case .success:
                // Получаем сохраненный email для текущего пользователя
                if let userID = UserDefaults.standard.string(forKey: "lastLoggedInUserID"),
                   let savedEmail = BiometricAuthManager.shared.getAuthCredentials(for: userID) {
                    
                    // Автоматически входим с сохраненными данными, если они есть
                    self.email = savedEmail
                    
                    // Проверяем, есть ли активная сессия Firebase
                    if Auth.auth().currentUser != nil {
                        isLoggedIn = true
                    } else {
                        errorMessage = "Please enter your password to complete login"
                    }
                }
            case .failure(let error):
                switch error {
                case .userCancelled:
                    // Пользователь отменил - не показываем ошибку
                    break
                case .biometryNotEnrolled:
                    errorMessage = "Biometric authentication not set up on this device"
                case .biometryLockout:
                    errorMessage = "Biometric authentication is locked. Please use your password"
                default:
                    errorMessage = "Biometric authentication failed"
                }
            }
        }
    }
    
    func saveBiometricCredentials(user: User) {
        // Сохраняем учетные данные для биометрии
        BiometricAuthManager.shared.setBiometricAuthEnabled(true, for: user.uid)
        BiometricAuthManager.shared.saveAuthCredentials(userID: user.uid, email: email)
        UserDefaults.standard.set(user.uid, forKey: "lastLoggedInUserID")
    }
    
    func checkSavedCredentials() {
        // Проверяем, есть ли сохраненный пользователь
        if let userID = UserDefaults.standard.string(forKey: "lastLoggedInUserID"),
           BiometricAuthManager.shared.isBiometricAuthEnabled(for: userID) {
            // Если для этого пользователя включена биометрия, показываем кнопку
            showBiometricButton = true
        } else if let savedEmail = UserDefaults.standard.string(forKey: "savedEmail") {
            // Иначе просто заполняем email
            email = savedEmail
        }
    }
}

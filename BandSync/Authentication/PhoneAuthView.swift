import SwiftUI
import FirebaseAuth

struct PhoneAuthView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var isLoggedIn: Bool
    
    @State private var phoneNumber = ""
    @State private var verificationID: String?
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var linkToExistingAccount = false
    @State private var isSuccess = false

    var body: some View {
        VStack {
            Text("Phone Verification")
                .font(.largeTitle)
                .bold()
                .padding()

            if isSuccess {
                // Успешная верификация
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.green)
                    
                    Text("Verification Successful!")
                        .font(.title)
                        .bold()
                    
                    Text("Your phone number has been verified and linked to your account.")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            } else if !isCodeSent {
                // Шаг 1: Ввод номера телефона
                VStack(spacing: 20) {
                    Text("Enter your phone number to receive a verification code")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    TextField("Phone Number (e.g. +380501234567)", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                        .padding()

                    if Auth.auth().currentUser != nil {
                        Toggle("Link to my existing account", isOn: $linkToExistingAccount)
                            .padding(.horizontal)
                    }

                    Button(action: sendCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Send Code")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading || phoneNumber.count < 10 ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading || phoneNumber.count < 10)
                }
            } else {
                // Шаг 2: Ввод кода подтверждения
                VStack(spacing: 20) {
                    Text("Enter the verification code sent to \(phoneNumber)")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    TextField("Verification Code", text: $verificationCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .padding()

                    Button(action: verifyCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Verify Code")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading || verificationCode.count < 6 ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading || verificationCode.count < 6)
                    
                    Button(action: {
                        // Вернуться назад для изменения номера телефона
                        isCodeSent = false
                    }) {
                        Text("Change Phone Number")
                            .foregroundColor(.blue)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Кнопка закрытия экрана
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .foregroundColor(.blue)
            }
            .padding()
        }
        .padding()
        .disabled(isLoading)
    }

    func sendCode() {
        isLoading = true
        errorMessage = ""
        
        // Форматирование номера телефона
        var formattedNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formattedNumber.hasPrefix("+") {
            formattedNumber = "+" + formattedNumber
        }
        
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedNumber, uiDelegate: nil) { verificationID, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                } else if let verificationID = verificationID {
                    self.verificationID = verificationID
                    isCodeSent = true
                }
            }
        }
    }

    func verifyCode() {
        isLoading = true
        errorMessage = ""
        
        guard let verificationID = verificationID else {
            errorMessage = "Error: No verification ID"
            isLoading = false
            return
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        // Если пользователь уже вошел в систему и хочет привязать номер
        if let currentUser = Auth.auth().currentUser, linkToExistingAccount {
            currentUser.link(with: credential) { result, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        errorMessage = "Error: \(error.localizedDescription)"
                    } else {
                        // Успешно связали номер телефона с аккаунтом
                        isSuccess = true
                    }
                }
            }
        } else {
            // Если пользователь не вошел, выполняем вход по номеру телефона
            Auth.auth().signIn(with: credential) { result, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        errorMessage = "Error: \(error.localizedDescription)"
                    } else {
                        // Успешная аутентификация по телефону
                        isSuccess = true
                        
                        // Если это новый вход, устанавливаем флаг
                        if !linkToExistingAccount {
                            isLoggedIn = true
                        }
                    }
                }
            }
        }
    }
}

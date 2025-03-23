import Foundation
import LocalAuthentication

class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    enum BiometricType {
        case none
        case touchID
        case faceID
    }
    
    enum AuthError: Error {
        case authenticationFailed
        case userCancelled
        case biometryNotAvailable
        case biometryNotEnrolled
        case biometryLockout
        case unknown
        
        var message: String {
            switch self {
            case .authenticationFailed: return "Authentication failed"
            case .userCancelled: return "User cancelled"
            case .biometryNotAvailable: return "Biometric authentication is not available"
            case .biometryNotEnrolled: return "No biometric data is enrolled"
            case .biometryLockout: return "Biometric authentication is locked out"
            case .unknown: return "Unknown error occurred"
            }
        }
    }
    
    private let context = LAContext()
    private let biometricAuthKey = "BiometricAuthEnabled"
    private let userDefaultsKeyPrefix = "BiometricUser_"
    
    private init() {}
    
    // Проверяем доступность биометрии
    var biometricType: BiometricType {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        default:
            return .none
        }
    }
    
    // Проверяем, включена ли биометрическая аутентификация
    func isBiometricAuthEnabled(for userID: String) -> Bool {
        return UserDefaults.standard.bool(forKey: userDefaultsKeyPrefix + userID)
    }
    
    // Включаем/выключаем биометрическую аутентификацию
    func setBiometricAuthEnabled(_ enabled: Bool, for userID: String) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKeyPrefix + userID)
    }
    
    // Сохраняем данные аутентификации в связке ключей
    func saveAuthCredentials(userID: String, email: String) {
        let keychainService = KeychainManager()
        try? keychainService.save(email, for: userID)
    }
    
    // Получаем сохраненные данные аутентификации
    func getAuthCredentials(for userID: String) -> String? {
        let keychainService = KeychainManager()
        return try? keychainService.get(for: userID)
    }
    
    // Выполняем биометрическую аутентификацию
    func authenticate(completion: @escaping (Result<Bool, AuthError>) -> Void) {
        // Проверяем, доступна ли биометрия на устройстве
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                let authError: AuthError
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    authError = .biometryNotEnrolled
                case LAError.biometryLockout.rawValue:
                    authError = .biometryLockout
                default:
                    authError = .biometryNotAvailable
                }
                completion(.failure(authError))
            } else {
                completion(.failure(.unknown))
            }
            return
        }
        
        // Выполняем аутентификацию
        let reason = "Log in to your account"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(true))
                } else if let error = error {
                    let authError: AuthError
                    switch (error as? LAError)?.code {
                    case .some(.userCancel):
                        authError = .userCancelled
                    case .some(.biometryNotEnrolled):
                        authError = .biometryNotEnrolled
                    case .some(.biometryLockout):
                        authError = .biometryLockout
                    default:
                        authError = .authenticationFailed
                    }
                    completion(.failure(authError))
                } else {
                    completion(.failure(.unknown))
                }
            }
        }
    }
}

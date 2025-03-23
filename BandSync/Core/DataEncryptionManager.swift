// Необходимо добавить класс для шифрования локальных данных
import Foundation
import CommonCrypto

class DataEncryptionManager {
    static let shared = DataEncryptionManager()
    
    private let keyChainManager = KeychainManager()
    private let encryptionKeyIdentifier = "com.bandsync.encryptionKey"
    
    private init() {
        // Проверяем наличие ключа шифрования при инициализации
        if getEncryptionKey() == nil {
            generateEncryptionKey()
        }
    }
    
    // Генерация и сохранение ключа шифрования
    private func generateEncryptionKey() {
        var keyData = Data(count: 32) // 256-bit key
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        
        if result == errSecSuccess {
            do {
                try keyChainManager.save(keyData.base64EncodedString(), for: encryptionKeyIdentifier)
            } catch {
                print("Error saving encryption key: \(error.localizedDescription)")
            }
        }
    }
    
    // Получение ключа шифрования
    private func getEncryptionKey() -> Data? {
        do {
            let keyString = try keyChainManager.get(for: encryptionKeyIdentifier)
            return Data(base64Encoded: keyString)
        } catch {
            return nil
        }
    }
    
    // Шифрование данных
    func encrypt(data: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            print("Encryption key not available")
            return nil
        }
        
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted = 0
        
        let iv = generateIV()
        
        let status = key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress!,
                            key.count,
                            ivBytes.baseAddress!,
                            dataBytes.baseAddress!,
                            data.count,
                            bufferBytes.baseAddress!,
                            bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        if status != kCCSuccess {
            print("Error encrypting data: \(status)")
            return nil
        }
        
        buffer.count = numBytesEncrypted
        
        // Добавляем IV в начало зашифрованных данных
        var encryptedData = iv
        encryptedData.append(buffer)
        
        return encryptedData
    }
    
    // Расшифровка данных
    func decrypt(encryptedData: Data) -> Data? {
        guard let key = getEncryptionKey() else {
            print("Encryption key not available")
            return nil
        }
        
        // Извлекаем IV из начала зашифрованных данных
        let iv = encryptedData.prefix(16)
        let encryptedBytes = encryptedData.suffix(from: 16)
        
        let bufferSize = encryptedBytes.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0
        
        let status = key.withUnsafeBytes { keyBytes in
            encryptedBytes.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress!,
                            key.count,
                            ivBytes.baseAddress!,
                            dataBytes.baseAddress!,
                            encryptedBytes.count,
                            bufferBytes.baseAddress!,
                            bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        if status != kCCSuccess {
            print("Error decrypting data: \(status)")
            return nil
        }
        
        buffer.count = numBytesDecrypted
        return buffer
    }
    
    // Генерация вектора инициализации (IV)
    private func generateIV() -> Data {
        var iv = Data(count: kCCBlockSizeAES128)
        let result = iv.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, $0.baseAddress!)
        }
        
        if result != errSecSuccess {
            print("Error generating IV: \(result)")
        }
        
        return iv
    }
    
    // Автоматическая очистка данных после определенного периода
    func scheduleDataWipe(after days: Int) {
        // Сохраняем дату последнего использования
        UserDefaults.standard.set(Date(), forKey: "app_last_use_date")
    }
    
    // Проверка необходимости очистки данных при запуске
    func checkDataWipe(days: Int) -> Bool {
        if let lastUseDate = UserDefaults.standard.object(forKey: "app_last_use_date") as? Date {
            let calendar = Calendar.current
            if let expirationDate = calendar.date(byAdding: .day, value: days, to: lastUseDate) {
                if Date() > expirationDate {
                    return true
                }
            }
        }
        return false
    }
    
    // Выполнение очистки конфиденциальных данных
    func performDataWipe() {
        // Очистка ключа шифрования
        try? keyChainManager.delete(for: encryptionKeyIdentifier)
        
        // Сброс настроек биометрии
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys where key.hasPrefix("BiometricUser_") {
            userDefaults.removeObject(forKey: key)
        }
        
        userDefaults.removeObject(forKey: "lastLoggedInUserID")
        userDefaults.synchronize()
        
        // Генерируем новый ключ
        generateEncryptionKey()
    }
}

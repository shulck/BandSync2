import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language {
        didSet {
            // Сохраняем выбранный язык в UserDefaults
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            updateLocale()
            
            // Публикуем уведомление о смене языка
            NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
        }
    }
    
    // Доступные языки приложения в соответствии с ТЗ
    let availableLanguages: [Language] = [.english, .german, .ukrainian]
    
    private init() {
        // Получаем сохраненный язык или используем системный язык по умолчанию
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Определяем язык по системным настройкам
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            
            if preferredLanguage.hasPrefix("de") {
                self.currentLanguage = .german
            } else if preferredLanguage.hasPrefix("uk") {
                self.currentLanguage = .ukrainian
            } else {
                self.currentLanguage = .english
            }
        }
        
        updateLocale()
    }
    
    private func updateLocale() {
        // Устанавливаем локаль для приложения
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    // Функция для получения локализованной строки
    func localizedString(_ key: String, defaultValue: String = "") -> String {
        let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        let localizedString = NSLocalizedString(key, tableName: nil, bundle: bundle ?? Bundle.main, value: "", comment: "")
        
        // Если перевод отсутствует, возвращаем defaultValue или ключ
        return localizedString == key ? (defaultValue.isEmpty ? key : defaultValue) : localizedString
    }
    
    // Функция для смены языка
    func setLanguage(_ language: Language) {
        self.currentLanguage = language
    }
}

// Перечисление поддерживаемых языков
enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"
    case ukrainian = "uk"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English 🇬🇧"
        case .german: return "Deutsch 🇩🇪"
        case .ukrainian: return "Українська 🇺🇦"
        }
    }
    
    var locale: Locale {
        return Locale(identifier: self.rawValue)
    }
}

// Окружение для внедрения языковых настроек в SwiftUI
struct LocalizationEnvironmentKey: EnvironmentKey {
    static let defaultValue: Language = .english
}

extension EnvironmentValues {
    var currentLanguage: Language {
        get { self[LocalizationEnvironmentKey.self] }
        set { self[LocalizationEnvironmentKey.self] = newValue }
    }
}

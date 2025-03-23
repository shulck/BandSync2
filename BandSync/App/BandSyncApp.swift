import SwiftUI
import Firebase
import FirebaseAuth  // Добавляем импорт
import FirebaseFirestore

@main
struct BandSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var appReloadTrigger = UUID()

    let persistenceController = PersistenceController.shared

    init() {
        // Глобальный наблюдатель для смены языка
        NotificationCenter.default.addObserver(
            forName: Notification.Name("LanguageChanged"),
            object: nil,
            queue: .main
        ) { _ in
            // Этот код будет выполнен при смене языка
            print("🌐 Язык изменен на: \(LocalizationManager.shared.currentLanguage.rawValue)")
        }
        
        // Наблюдатель для принудительной перезагрузки приложения
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceAppReload"),
            object: nil,
            queue: .main
        ) { [self] _ in
            // Смена этого идентификатора заставит SwiftUI полностью перестроить приложение
            self.appReloadTrigger = UUID()
            print("🔄 Принудительная перезагрузка приложения")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(localizationManager)
                .id(appReloadTrigger) // Ключевой момент: перезагрузка при смене ID
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("🔥 Firebase успішно ініціалізовано!")
        Firestore.firestore() // Ініціалізація Firestore
        
        // Настраиваем параметры безопасности согласно ТЗ
        configureSecuritySettings()
        
        return true
    }
    
    private func configureSecuritySettings() {
        // Настройка безопасности и защиты данных
        
        // 1. Настройка параметров аутентификации Firebase
        let auth = Auth.auth()
        auth.settings?.isAppVerificationDisabledForTesting = false
        
        // 2. Настройка безопасности Firestore
        let db = Firestore.firestore()
        let settings = db.settings
        // Используем последнюю версию TLS
        settings.isSSLEnabled = true  // Исправлено с sslEnabled на isSSLEnabled
        db.settings = settings
        
        // 3. Настройка шифрования локальных данных (в реальном приложении)
        // В iOS для защиты данных используется Data Protection API
        // и Keychain для хранения чувствительных данных
        
        // 4. Логгирование важных операций безопасности
        print("🔐 Security settings configured successfully")
    }
}

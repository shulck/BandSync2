import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage // Добавлен импорт Firebase Storage
import UserNotifications

@main
struct BandSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var appReloadTrigger = UUID()

    let persistenceController = PersistenceController.shared

    init() {
        // Инициализируем сервис уведомлений
        let _ = NotificationService.shared
        
        // Глобальный наблюдатель для смены языка
        NotificationCenter.default.addObserver(
            forName: Notification.Name("LanguageChanged"),
            object: nil,
            queue: .main
        ) { _ in
            // Этот код будет выполнен при смене языка
            print("🌐 Language changed to: \(LocalizationManager.shared.currentLanguage.rawValue)")
        }
        
        // Наблюдатель для принудительной перезагрузки приложения
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceAppReload"),
            object: nil,
            queue: .main
        ) { [self] _ in
            // Смена этого идентификатора заставит SwiftUI полностью перестроить приложение
            self.appReloadTrigger = UUID()
            print("🔄 Forced app reload")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(localizationManager)
                .id(appReloadTrigger) // Перезагрузка при смене ID
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("🔥 Firebase successfully initialized!")
        Firestore.firestore() // Инициализация Firestore
        Storage.storage() // Инициализация Firebase Storage
        
        // Настройка центра уведомлений
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.setupNotificationActions()
        
        // Настройка безопасности
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
        settings.isSSLEnabled = true
        db.settings = settings
        
        // 3. Логгирование важных операций безопасности
        print("🔐 Security settings configured successfully")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Показываем уведомление, даже если приложение в фокусе
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Обрабатываем нажатие на уведомление
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_EVENT":
            // Открываем детали события
            if let eventId = userInfo["eventId"] as? String {
                // Здесь код для навигации к деталям события
                print("Opening event with ID: \(eventId)")
            }
        case "REMIND_LATER":
            // Напоминаем позже
            if let eventId = userInfo["eventId"] as? String,
               let eventTitle = userInfo["eventTitle"] as? String,
               let eventLocation = userInfo["eventLocation"] as? String {
                
                // Создаем новое уведомление через 30 минут
                let content = UNMutableNotificationContent()
                content.title = "Reminder: \(eventTitle)"
                content.body = "Location: \(eventLocation)"
                content.sound = .default
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
                let request = UNNotificationRequest(identifier: "reminder-later-\(eventId)", content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling reminder: \(error.localizedDescription)")
                    }
                }
            }
        default:
            // Обработка стандартного нажатия
            if let eventId = userInfo["eventId"] as? String {
                print("Opening event with ID: \(eventId)")
            }
        }
        
        completionHandler()
    }
}

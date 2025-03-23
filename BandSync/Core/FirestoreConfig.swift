import Foundation
import FirebaseFirestore
import FirebaseAuth

// Этот класс служит для централизованного доступа к Firestore
// и стандартизации базовых операций с базой данных
class FirestoreService {
    // Общий экземпляр для использования во всем приложении
    static let shared = FirestoreService()
    
    // Экземпляр Firestore
    private let db = Firestore.firestore()
    
    private init() {
        // Настройка Firestore выполняется автоматически Firebase SDK
        // Не используем устаревшие свойства
        print("🔥 Firestore initialized successfully")
    }
    
    // MARK: - Общие методы
    
    // Получить текущий ID пользователя
    func currentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Получить информацию о группе текущего пользователя
    func getCurrentUserGroup(completion: @escaping (String?, String?, Error?) -> Void) {
        guard let userId = currentUserId() else {
            completion(nil, nil, NSError(domain: "FirestoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(nil, nil, error)
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                completion(nil, nil, NSError(domain: "FirestoreService", code: 2, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }
            
            guard let groupId = data["groupId"] as? String else {
                completion(nil, nil, NSError(domain: "FirestoreService", code: 3, userInfo: [NSLocalizedDescriptionKey: "User has no group"]))
                return
            }
            
            // Get group name
            self.db.collection("groups").document(groupId).getDocument { groupDoc, error in
                if let error = error {
                    completion(groupId, nil, error)
                    return
                }
                
                guard let groupDoc = groupDoc, let groupData = groupDoc.data() else {
                    completion(groupId, nil, NSError(domain: "FirestoreService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Group document not found"]))
                    return
                }
                
                let groupName = groupData["name"] as? String ?? "Unknown Group"
                completion(groupId, groupName, nil)
            }
        }
    }
    
    // MARK: - Вспомогательные методы
    
    // Генерировать уникальный код группы
    func generateGroupCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Без похожих символов
        return String((0..<6).map{ _ in letters.randomElement()! })
    }
    
    // Проверить существует ли код группы
    func checkGroupCode(_ code: String, completion: @escaping (Bool, Error?) -> Void) {
        db.collection("groups").whereField("code", isEqualTo: code).getDocuments { snapshot, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let snapshot = snapshot else {
                completion(false, nil)
                return
            }
            
            completion(!snapshot.documents.isEmpty, nil)
        }
    }
    
    // MARK: - Методы для работы с пользователями
    
    // Получить роль пользователя
    func getUserRole(completion: @escaping (String?, Error?) -> Void) {
        guard let userId = currentUserId() else {
            completion(nil, NSError(domain: "FirestoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                completion(nil, NSError(domain: "FirestoreService", code: 2, userInfo: [NSLocalizedDescriptionKey: "User document not found"]))
                return
            }
            
            let role = data["role"] as? String ?? "Unknown"
            completion(role, nil)
        }
    }
    
    // MARK: - Доступ к коллекциям Firestore
    
    // Получить ссылку на коллекцию пользователей
    func usersCollection() -> CollectionReference {
        return db.collection("users")
    }
    
    // Получить ссылку на коллекцию групп
    func groupsCollection() -> CollectionReference {
        return db.collection("groups")
    }
    
    // Получить ссылку на коллекцию событий
    func eventsCollection() -> CollectionReference {
        return db.collection("events")
    }
    
    // Получить ссылку на коллекцию сетлистов
    func setlistsCollection() -> CollectionReference {
        return db.collection("setlists")
    }
    
    // Получить ссылку на коллекцию задач
    func tasksCollection() -> CollectionReference {
        return db.collection("tasks")
    }
    
    // Получить ссылку на коллекцию чатов
    func chatRoomsCollection() -> CollectionReference {
        return db.collection("chatRooms")
    }
    
    // Получить ссылку на коллекцию контактов
    func contactsCollection() -> CollectionReference {
        return db.collection("contacts")
    }
    
    // Получить ссылку на коллекцию финансов
    func financesCollection() -> CollectionReference {
        return db.collection("finances")
    }
}

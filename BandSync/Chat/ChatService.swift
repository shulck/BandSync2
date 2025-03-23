import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatService: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var messages: [ChatMessage] = []
    
    private let db = Firestore.firestore()
    private var chatRoomsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    // Текущий пользователь
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    var currentUserName: String {
        return Auth.auth().currentUser?.displayName ?? "Участник"
    }
    
    // Получение списка чатов для текущего пользователя
    func fetchChatRooms() {
        guard let userId = currentUserId else {
            print("⛔️ Не удалось получить ID пользователя")
            return
        }
        
        print("🔄 Загрузка чатов для пользователя: \(userId)")
        
        chatRoomsListener?.remove()
        
        chatRoomsListener = db.collection("chatRooms")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("⛔️ Ошибка при получении чатов: \(error.localizedDescription)")
                    return
                }
                
                print("✅ Получено чатов: \(querySnapshot?.documents.count ?? 0)")
                
                self.chatRooms = querySnapshot?.documents.compactMap { document -> ChatRoom? in
                    let chatRoom = ChatRoom(document: document)
                    print("📝 Чат: \(chatRoom?.name ?? "без имени")")
                    return chatRoom
                } ?? []
                
                print("🏁 Всего загружено чатов: \(self.chatRooms.count)")
            }
    }
    
    // Получение сообщений для конкретного чата
    func fetchMessages(for chatRoomId: String) {
        messagesListener?.remove()
        
        messagesListener = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("⛔️ Ошибка при получении сообщений: \(error.localizedDescription)")
                    return
                }
                
                self.messages = querySnapshot?.documents.compactMap { document in
                    return ChatMessage(document: document)
                } ?? []
                
                // Отмечаем сообщения как прочитанные
                self.markMessagesAsRead(in: chatRoomId)
            }
    }
    
    // Отправка нового сообщения
    func sendMessage(text: String, in chatRoomId: String) {
        guard let userId = currentUserId, !text.isEmpty else { return }
        
        let message = ChatMessage(
            senderId: userId,
            senderName: currentUserName,
            text: text
        )
        
        // Добавляем сообщение в коллекцию
        let messageRef = db.collection("chatRooms")
            .document(chatRoomId)
            .collection("messages")
            .document()
        
        messageRef.setData(message.asDict) { error in
            if let error = error {
                print("⛔️ Ошибка при отправке сообщения: \(error.localizedDescription)")
            } else {
                // Обновляем информацию о последнем сообщении в чате
                self.updateLastMessage(text: text, in: chatRoomId)
            }
        }
    }
    
    // Обновление информации о последнем сообщении
    private func updateLastMessage(text: String, in chatRoomId: String) {
        let chatRef = db.collection("chatRooms").document(chatRoomId)
        
        chatRef.updateData([
            "lastMessage": text,
            "lastMessageDate": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("⛔️ Ошибка при обновлении последнего сообщения: \(error.localizedDescription)")
            }
        }
    }
    
    // Создание нового чата
    func createChat(name: String, participants: [String], isGroupChat: Bool = false) {
        guard let userId = currentUserId else {
            print("⛔️ Не удалось получить ID пользователя для создания чата")
            return
        }
        
        // Убеждаемся, что текущий пользователь включен в участников
        var allParticipants = participants
        if !allParticipants.contains(userId) {
            allParticipants.append(userId)
        }
        
        print("🔄 Создание чата: \(name) с \(allParticipants.count) участниками")
        
        let chatRoom = ChatRoom(
            name: name,
            participants: allParticipants,
            lastMessageDate: Date(),
            isGroupChat: isGroupChat
        )
        
        let newChatRef = db.collection("chatRooms").document()
        
        newChatRef.setData(chatRoom.asDict) { error in
            if let error = error {
                print("⛔️ Ошибка при создании чата: \(error.localizedDescription)")
            } else {
                print("✅ Чат успешно создан, ID: \(newChatRef.documentID)")
                
                // Обновляем список чатов
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchChatRooms()
                }
            }
        }
    }
    
    // Отметка сообщений как прочитанных
    private func markMessagesAsRead(in chatRoomId: String) {
        guard let userId = currentUserId else { return }
        
        // Находим непрочитанные сообщения от других пользователей
        let unreadMessages = messages.filter {
            $0.senderId != userId && !$0.isRead
        }
        
        for message in unreadMessages {
            db.collection("chatRooms")
                .document(chatRoomId)
                .collection("messages")
                .document(message.id)
                .updateData(["isRead": true])
        }
    }
    
    // Отмена подписок при выходе из чата
    func stopListening() {
        chatRoomsListener?.remove()
        messagesListener?.remove()
    }
}

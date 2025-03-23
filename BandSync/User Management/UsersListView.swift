import SwiftUI
import FirebaseFirestore

struct UsersListView: View {
    @State private var users: [(id: String, email: String, role: String)] = []

    var body: some View {
        VStack {
            Text("📋 Список пользователей")
                .font(.title)
                .bold()
                .padding()

            List(users, id: \.id) { user in
                HStack {
                    VStack(alignment: .leading) {
                        Text(user.email)
                            .bold()
                        Text("Роль: \(user.role)")
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    Menu {
                        Button("Назначить Админом") {
                            updateUserRole(userID: user.id, newRole: "Admin")
                        }
                        Button("Назначить Менеджером") {
                            updateUserRole(userID: user.id, newRole: "Manager")
                        }
                        Button("Назначить Музыкантом") {
                            updateUserRole(userID: user.id, newRole: "Musician")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .onAppear {
            fetchUsers()
        }
    }

    /// 📡 Функция загрузки пользователей
    func fetchUsers() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Ошибка загрузки: \(error.localizedDescription)")
                return
            }

            self.users = snapshot?.documents.map { doc in
                let data = doc.data()
                return (
                    id: doc.documentID,
                    email: data["email"] as? String ?? "Нет email",
                    role: data["role"] as? String ?? "Неизвестно"
                )
            } ?? []
        }
    }

    /// 🔥 Функция обновления роли пользователя
    func updateUserRole(userID: String, newRole: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData(["role": newRole]) { error in
            if let error = error {
                print("❌ Ошибка обновления роли: \(error.localizedDescription)")
            } else {
                print("✅ Роль обновлена на \(newRole) для пользователя \(userID)")
                fetchUsers()  // Перезагружаем список
            }
        }
    }
}


import SwiftUI
import FirebaseAuth

struct RoleView: View {
    var userRole: String

    var body: some View {
        VStack {
            Text("🔷 Ваша роль: \(userRole)")
                .font(.largeTitle)
                .bold()
                .padding()

            Button(action: logout) {
                Text("Выйти")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            print("🚪 Пользователь вышел из системы")
        } catch {
            print("❌ Ошибка выхода: \(error.localizedDescription)")
        }
    }
}


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var userRole: String = "Loading..."
    @State private var isLoggedIn = false
    @State private var refreshUI = false  // Флаг для форсирования обновления UI
    @State private var groupId: String = ""
    @State private var groupName: String = ""

    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(userRole: userRole, groupId: groupId, groupName: groupName)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear {
            checkAuth()
            setupObservers()
        }
        .id(refreshUI)  // Использование флага для форсирования обновления при его изменении
    }

    func checkAuth() {
        if let user = Auth.auth().currentUser {
            isLoggedIn = true
            fetchUserData(user: user)
        } else {
            isLoggedIn = false
            userRole = "Unknown"
            groupId = ""
            groupName = ""
        }
    }

    func fetchUserData(user: User) {
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                userRole = "Error"
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                print("User document does not exist")
                userRole = "Unknown"
                return
            }
            
            // Get user role
            self.userRole = data["role"] as? String ?? "Unknown"
            
            // Get group ID
            if let gId = data["groupId"] as? String {
                self.groupId = gId
                
                // Fetch group name
                db.collection("groups").document(gId).getDocument { groupDoc, error in
                    if let error = error {
                        print("Error fetching group: \(error.localizedDescription)")
                        return
                    }
                    
                    if let groupDoc = groupDoc, groupDoc.exists, let groupData = groupDoc.data() {
                        self.groupName = groupData["name"] as? String ?? "Unknown Group"
                    }
                }
            }
        }
    }
    
    func setupObservers() {
        // Наблюдатель для смены языка
        NotificationCenter.default.addObserver(
            forName: Notification.Name("LanguageChanged"),
            object: nil,
            queue: .main
        ) { _ in
            // Форсируем обновление UI при смене языка
            self.refreshUI.toggle()
        }
        
        // Наблюдатель для выхода пользователя
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LogoutUser"),
            object: nil,
            queue: .main
        ) { _ in
            self.isLoggedIn = false
            self.userRole = "Unknown"
            self.groupId = ""
            self.groupName = ""
        }
    }
}

import Foundation
import SwiftUI

// MARK: - User Models

/// Основная модель пользователя, используется во всем приложении
struct UserModel: Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    var phone: String = ""
    var groupId: String = ""
    
    // Дополнительный конструктор с минимумом полей
    init(id: String, email: String, name: String, role: String) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
    }
    
    // Полный конструктор
    init(id: String, email: String, name: String, role: String, phone: String, groupId: String) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.phone = phone
        self.groupId = groupId
    }
}

/// Базовая информация о пользователе, используется для отображения в списках
struct UserInfo: Identifiable {
    let id: String
    let name: String
    let email: String
    
    init(id: String, name: String, email: String = "") {
        self.id = id
        self.name = name
        self.email = email
    }
}

// MARK: - Row Components for User Display

/// Строка для отображения ожидающего подтверждения пользователя
struct PendingUserRow: View {
    let user: UserModel
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(user.name)
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onApprove) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 4)
            
            Button(action: onReject) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 4)
    }
}

/// Строка для отображения активного пользователя
struct ActiveUserRow: View {
    let user: UserModel
    let onChangeRole: (String) -> Void
    let onRemove: () -> Void
    @State private var showingRoleOptions = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(user.name)
                    .font(.headline)
                HStack {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(user.role)
                        .font(.caption)
                        .foregroundColor(roleColor(user.role))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor(user.role).opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingRoleOptions = true
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 4)
            .actionSheet(isPresented: $showingRoleOptions) {
                ActionSheet(
                    title: Text("Change Role"),
                    message: Text("Select a new role for \(user.name)"),
                    buttons: [
                        .default(Text("Admin")) { onChangeRole("Admin") },
                        .default(Text("Manager")) { onChangeRole("Manager") },
                        .default(Text("Member")) { onChangeRole("Member") },
                        .cancel()
                    ]
                )
            }
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 4)
    }
    
    func roleColor(_ role: String) -> Color {
        switch role {
        case "Admin":
            return .red
        case "Manager":
            return .orange
        case "Member":
            return .blue
        default:
            return .gray
        }
    }
}

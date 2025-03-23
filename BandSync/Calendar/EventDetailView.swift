import SwiftUI
import FirebaseFirestore
import MapKit

struct EventDetailView: View {
    let event: Event
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMap = false
    @State private var showingEdit = false
    @State private var showingSetlistPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовок для всех типов событий
                headerSection

                Divider()
                
                // Локация для всех типов событий
                locationSection

                // Организатор - нужен для всех, кроме возможно репетиции
                if eventNeedsOrganizer(event.type) || !event.organizer.name.isEmpty {
                    contactSection(title: "Організатор", contact: event.organizer)
                }
                
                // Координатор - нужен для концертов и фестивалей
                if eventNeedsCoordinator(event.type) || !event.coordinator.name.isEmpty {
                    contactSection(title: "Координатор", contact: event.coordinator)
                }

                // Отель - по типу события
                if eventNeedsHotel(event.type) && (!event.hotel.address.isEmpty || !event.hotel.checkIn.isEmpty) {
                    hotelSection
                }
                
                // Гонорар - для концертов, фестивалей и иногда фотосессий
                if eventNeedsFee(event.type) && !event.fee.isEmpty {
                    feeSection
                }
                
                // Сетлист - для концертов, фестивалей и репетиций
                if eventNeedsSetlist(event.type) {
                    if event.setlist.isEmpty {
                        Button(action: {
                            showingSetlistPicker = true
                        }) {
                            Label("Connect Setlist", systemImage: "music.note.list")
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    } else {
                        setlistSection
                    }
                }
                
                // Расписание дня - для всех типов событий
                if !event.schedule.isEmpty {
                    scheduleSection
                }
                
                // Заметки - для всех типов событий
                if !event.notes.isEmpty {
                    notesSection
                }

                if showingMap {
                    MapLocationView(address: event.location)
                        .frame(height: 250)
                        .cornerRadius(12)
                        .padding(.vertical, 4)
                }

                actionsSection
            }
            .padding()
        }
        .navigationTitle("Деталі події")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingSetlistPicker) {
            SetlistPickerView(selectedSetlist: .constant([]))
        }
    }
    
    // MARK: - Event Type Requirements
    
    // Проверяем, нужен ли сетлист для данного типа события
    func eventNeedsSetlist(_ type: String) -> Bool {
        return ["Concert", "Festival", "Rehearsal"].contains(type)
    }
    
    // Проверяем, нужна ли информация об отеле
    func eventNeedsHotel(_ type: String) -> Bool {
        // Для концертов, фестивалей точно да
        // Для встреч, фотосессий и интервью - возможно
        return ["Concert", "Festival", "Meeting", "Photo Session", "Interview"].contains(type)
    }
    
    // Проверяем, нужен ли гонорар
    func eventNeedsFee(_ type: String) -> Bool {
        return ["Concert", "Festival", "Photo Session"].contains(type)
    }
    
    // Проверяем, нужен ли координатор
    func eventNeedsCoordinator(_ type: String) -> Bool {
        return ["Concert", "Festival"].contains(type)
    }
    
    // Проверяем, нужен ли организатор
    func eventNeedsOrganizer(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"].contains(type)
    }

    // MARK: - UI Sections

    private var headerSection: some View {
        VStack(alignment: .leading) {
            Text(event.title)
                .font(.largeTitle).bold()
            Text("\(event.icon) \(event.type) • \(event.status)")
                .foregroundColor(.secondary)
            Text(event.date.formatted(date: .long, time: .shortened))
                .foregroundColor(.blue)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Локація", systemImage: "mappin.and.ellipse")
            Text(event.location).foregroundColor(.secondary)
            Button(action: {
                showingMap.toggle()
            }) {
                Label(showingMap ? "Сховати карту" : "Показати на карті",
                      systemImage: showingMap ? "map.fill" : "map")
                    .foregroundColor(.blue)
            }
        }
    }

    private func contactSection(title: String, contact: EventContact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "person")
            if !contact.name.isEmpty {
                Text("Ім'я: \(contact.name)")
            }
            
            if !contact.phone.isEmpty {
                Button(action: {
                    callPhoneNumber(contact.phone)
                }) {
                    Label(contact.phone, systemImage: "phone")
                        .foregroundColor(.blue)
                }
            }
            
            if !contact.email.isEmpty {
                Button(action: {
                    sendEmail(contact.email)
                }) {
                    Label(contact.email, systemImage: "envelope")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var hotelSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Готель", systemImage: "bed.double")
            if !event.hotel.address.isEmpty {
                Text("Адреса: \(event.hotel.address)")
            }
            
            if !event.hotel.checkIn.isEmpty {
                Text("Чек-ін: \(event.hotel.checkIn)")
            }
            
            if !event.hotel.checkOut.isEmpty {
                Text("Чек-аут: \(event.hotel.checkOut)")
            }
        }
    }

    private var feeSection: some View {
        Label("Гонорар: \(event.fee)", systemImage: "dollarsign.circle")
    }

    private var setlistSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Сетлист", systemImage: "music.note.list")
            ForEach(event.setlist, id: \.self) { song in
                HStack {
                    Text("🎵")
                    Text(song)
                }
                .padding(.vertical, 2)
            }
            Button(action: {
                showingSetlistPicker = true
            }) {
                Label("Change Setlist", systemImage: "pencil")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Розклад дня", systemImage: "calendar.badge.clock")
            VStack(alignment: .leading, spacing: 2) {
                ForEach(event.schedule) { item in
                    HStack(alignment: .top) {
                        Text(item.time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(item.activity)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.leading, 4)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Нотатки", systemImage: "note.text")
            Text(event.notes)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }

    private var actionsSection: some View {
        HStack {
            Button(action: {
                showingEdit = true
            }) {
                Label("Редагувати", systemImage: "pencil")
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Button(action: {
                shareEvent()
            }) {
                Label("Поділитися", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

            Button(action: deleteEvent) {
                Label("Видалити", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top)
    }

    // MARK: - Actions

    private func callPhoneNumber(_ phoneNumber: String) {
        let formattedPhone = phoneNumber.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(formattedPhone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func sendEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func shareEvent() {
        // Создаем текст для шаринга
        let shareText = """
        Event: \(event.title)
        Type: \(event.type)
        Date: \(event.date.formatted(date: .long, time: .shortened))
        Location: \(event.location)
        """
        
        // Создаем ссылку или любой другой контент для шаринга
        let items: [Any] = [shareText]
        
        // Показываем стандартный UI для шаринга
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Находим rootViewController для представления UI шаринга
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }

    func deleteEvent() {
        // Создаем алерт для подтверждения
        let alert = UIAlertController(
            title: "Удалить событие?",
            message: "Это действие нельзя отменить",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            // Удаляем событие из Firebase
            Firestore.firestore().collection("events").document(event.id).delete { error in
                if error == nil {
                    // Закрываем окно с деталями события
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("❌ Delete failed: \(error!.localizedDescription)")
                }
            }
        })
        
        // Показываем алерт
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}

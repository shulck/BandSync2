import SwiftUI
import FirebaseFirestore
import MapKit

struct AddEventView: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (Event) -> Void

    @State private var title = ""
    @State private var date = Date()
    @State private var type = "Concert"
    @State private var status = "Заброньовано"
    @State private var location = ""
    @State private var fee = ""
    @State private var notes = ""
    @State private var searchLocation = ""
    @State private var showingLocationSearch = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var organizer = EventContact(name: "", phone: "", email: "")
    @State private var coordinator = EventContact(name: "", phone: "", email: "")
    @State private var hotel = Hotel(address: "", checkIn: "", checkOut: "")

    @State private var setlist: [String] = []
    @State private var schedule: [DailyScheduleItem] = []
    @State private var showingSetlistPicker = false
    
    // Шаблоны для автоматического заполнения
    let eventTemplates: [String: [String: Any]] = [
        "Concert": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "16:00", activity: "Arrival & Setup"),
                DailyScheduleItem(time: "17:30", activity: "Soundcheck"),
                DailyScheduleItem(time: "19:00", activity: "Doors Open"),
                DailyScheduleItem(time: "20:00", activity: "Show Start"),
                DailyScheduleItem(time: "22:00", activity: "Show End & Merch")
            ]
        ],
        "Festival": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "12:00", activity: "Arrival & Check-in"),
                DailyScheduleItem(time: "14:30", activity: "Stage Setup"),
                DailyScheduleItem(time: "15:30", activity: "Soundcheck"),
                DailyScheduleItem(time: "17:00", activity: "Performance"),
                DailyScheduleItem(time: "18:00", activity: "Meet & Greet")
            ]
        ],
        "Rehearsal": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "10:00", activity: "Setup Equipment"),
                DailyScheduleItem(time: "10:30", activity: "Warm-up"),
                DailyScheduleItem(time: "11:00", activity: "Full Rehearsal"),
                DailyScheduleItem(time: "13:00", activity: "Break"),
                DailyScheduleItem(time: "14:00", activity: "Specific Songs Practice")
            ]
        ],
        "Photo Session": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "09:00", activity: "Makeup & Styling"),
                DailyScheduleItem(time: "10:30", activity: "Individual Shots"),
                DailyScheduleItem(time: "12:00", activity: "Group Shots"),
                DailyScheduleItem(time: "13:30", activity: "Break"),
                DailyScheduleItem(time: "14:30", activity: "Outdoor/Special Location Shots")
            ]
        ],
        "Interview": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "13:00", activity: "Arrival & Briefing"),
                DailyScheduleItem(time: "13:30", activity: "Sound & Light Check"),
                DailyScheduleItem(time: "14:00", activity: "Interview Start"),
                DailyScheduleItem(time: "15:00", activity: "B-roll Shooting"),
                DailyScheduleItem(time: "15:30", activity: "Wrap-up")
            ]
        ],
        "Meeting": [
            "scheduleTemplate": [
                DailyScheduleItem(time: "10:00", activity: "Meeting Start"),
                DailyScheduleItem(time: "11:30", activity: "Discussion"),
                DailyScheduleItem(time: "12:30", activity: "Lunch"),
                DailyScheduleItem(time: "13:30", activity: "Follow-up Planning"),
                DailyScheduleItem(time: "15:00", activity: "Meeting End")
            ]
        ]
    ]

    let eventTypes = ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"]
    let statusOptions = ["Заброньовано", "Підтверджено"]

    // MARK: - Event Type Requirements
    
    // Проверяем, нужен ли сетлист для данного типа события
    private func eventNeedsSetlist(_ type: String) -> Bool {
        return ["Concert", "Festival", "Rehearsal"].contains(type)
    }
    
    // Проверяем, нужна ли информация об отеле
    private func eventNeedsHotel(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Photo Session", "Interview"].contains(type)
    }
    
    // Проверяем, нужен ли гонорар
    private func eventNeedsFee(_ type: String) -> Bool {
        return ["Concert", "Festival", "Photo Session"].contains(type)
    }
    
    // Проверяем, нужен ли координатор
    private func eventNeedsCoordinator(_ type: String) -> Bool {
        return ["Concert", "Festival"].contains(type)
    }
    
    // Проверяем, нужен ли организатор
    private func eventNeedsOrganizer(_ type: String) -> Bool {
        return ["Concert", "Festival", "Meeting", "Rehearsal", "Photo Session", "Interview"].contains(type)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Основне")) {
                    TextField("Назва події", text: $title)
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Тип події", selection: $type) {
                        ForEach(eventTypes, id: \.self) { Text($0) }
                    }
                    .onChange(of: type) { newType in
                        // Автоматическое заполнение расписания в зависимости от типа события
                        if let template = eventTemplates[newType],
                           let scheduleTemplate = template["scheduleTemplate"] as? [DailyScheduleItem] {
                            schedule = scheduleTemplate
                        }
                    }
                    
                    Picker("Статус", selection: $status) {
                        ForEach(statusOptions, id: \.self) { Text($0) }
                    }
                    
                    HStack {
                        TextField("Локація", text: $location)
                        Button(action: {
                            showingLocationSearch = true
                        }) {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Секция организатора показывается для всех типов событий
                if eventNeedsOrganizer(type) {
                    Section(header: Text("Організатор")) {
                        TextField("Ім'я", text: $organizer.name)
                        TextField("Телефон", text: $organizer.phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $organizer.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }

                // Секция координатора показывается только для концертов и фестивалей
                if eventNeedsCoordinator(type) {
                    Section(header: Text("Координатор")) {
                        TextField("Ім'я", text: $coordinator.name)
                        TextField("Телефон", text: $coordinator.phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $coordinator.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }

                // Секция отеля показывается для определенных типов событий
                if eventNeedsHotel(type) {
                    Section(header: Text("Готель")) {
                        TextField("Адреса", text: $hotel.address)
                        TextField("Чек-ін", text: $hotel.checkIn)
                        TextField("Чек-аут", text: $hotel.checkOut)
                    }
                }

                // Секция гонорара показывается только для концертов, фестивалей и фотосессий
                if eventNeedsFee(type) {
                    Section(header: Text("Гонорар")) {
                        TextField("Сума", text: $fee)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Секция расписания показывается для всех типов событий
                Section(header: Text("Розклад дня")) {
                    ForEach(0..<schedule.count, id: \.self) { index in
                        HStack {
                            TextField("Час", text: Binding(
                                get: { schedule[index].time },
                                set: { schedule[index].time = $0 }
                            ))
                            .frame(width: 80)
                            .keyboardType(.numbersAndPunctuation)
                            
                            TextField("Подія", text: Binding(
                                get: { schedule[index].activity },
                                set: { schedule[index].activity = $0 }
                            ))
                        }
                    }
                    .onDelete(perform: deleteScheduleItem)
                    
                    Button(action: addScheduleItem) {
                        Label("Додати пункт розкладу", systemImage: "plus")
                    }
                }
                
                // Секция сетлиста показывается только для концертов, фестивалей и репетиций
                if eventNeedsSetlist(type) {
                    Section(header: Text("Сетлист")) {
                        if setlist.isEmpty {
                            Text("Сетлист не выбран")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(setlist, id: \.self) { song in
                                Text(song)
                            }
                            .onDelete { indices in
                                setlist.remove(atOffsets: indices)
                            }
                        }
                        
                        Button("Выбрать сетлист") {
                            showingSetlistPicker = true
                        }
                    }
                }
                
                // Заметки показываются для всех типов событий
                Section(header: Text("Нотатки")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                Button("Зберегти подію", action: saveEvent)
                    .disabled(title.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(title.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .navigationTitle("Нова подія")
            .navigationBarItems(leading: Button("Скасувати") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchView(selectedLocation: $location)
            }
            .sheet(isPresented: $showingSetlistPicker) {
                SetlistPickerView(selectedSetlist: $setlist)
            }
        }
    }
    
    func addScheduleItem() {
        let newItem = DailyScheduleItem(time: "12:00", activity: "")
        schedule.append(newItem)
    }
    
    func deleteScheduleItem(at offsets: IndexSet) {
        schedule.remove(atOffsets: offsets)
    }

    func saveEvent() {
        let db = Firestore.firestore()
        let event = Event(
            id: UUID().uuidString,
            title: title,
            date: date,
            type: type,
            status: status,
            location: location,
            organizer: organizer,
            coordinator: coordinator,
            hotel: hotel,
            fee: fee,
            setlist: setlist,
            notes: notes,
            schedule: schedule
        )

        db.collection("events").document(event.id).setData(event.asDictionary) { error in
            if let error = error {
                print("❌ Error saving event: \(error.localizedDescription)")
            } else {
                // Сохраняем контакты организатора и координатора в Firebase
                saveContact(organizer, role: "Organizer")
                saveContact(coordinator, role: "Coordinator")
                
                onSave(event)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // Функция для сохранения контактов в Firebase
    func saveContact(_ contact: EventContact, role: String) {
        // Проверяем, что хотя бы имя указано
        if contact.name.isEmpty {
            return // Пропускаем пустые контакты
        }
        
        let db = Firestore.firestore()
        let contactData: [String: Any] = [
            "name": contact.name,
            "phone": contact.phone,
            "email": contact.email,
            "role": role,
            "venue": location,
            "rating": 0,
            "notes": "",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Проверяем наличие контакта по имени (вместо телефона, который может быть пустым)
        db.collection("contacts")
            .whereField("name", isEqualTo: contact.name)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error checking contact: \(error.localizedDescription)")
                    return
                }
                
                if let snapshot = snapshot, snapshot.documents.isEmpty {
                    // Если контакт не существует, создаем новый с уникальным ID
                    db.collection("contacts").document().setData(contactData) { error in
                        if let error = error {
                            print("❌ Error saving contact: \(error.localizedDescription)")
                        } else {
                            print("✅ Contact saved successfully")
                        }
                    }
                } else {
                    // Если контакт существует, обновляем информацию
                    if let document = snapshot?.documents.first {
                        // Добавляем поле обновления
                        var updatedData = contactData
                        updatedData["updatedAt"] = FieldValue.serverTimestamp()
                        
                        db.collection("contacts").document(document.documentID).updateData(updatedData) { error in
                            if let error = error {
                                print("❌ Error updating contact: \(error.localizedDescription)")
                            } else {
                                print("✅ Contact updated successfully")
                            }
                        }
                    }
                }
            }
    }
}

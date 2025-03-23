import SwiftUI
import PDFKit

struct SetlistView: View {
    @State private var setlists: [Setlist] = []
    @State private var selectedSetlist: Setlist?
    @State private var isAddingNewSong = false
    @State private var showingEditSetlist = false
    @State private var totalDuration: TimeInterval = 0
    @State private var showingRehearsalMode = false
    
    var body: some View {
        NavigationView {
            VStack {
                if setlists.isEmpty {
                    VStack {
                        Text("No Setlists")
                            .font(.title)
                            .padding()
                        
                        Button("Create New Setlist") {
                            let newSetlist = Setlist(id: UUID().uuidString, name: "New Setlist", songs: [])
                            setlists.append(newSetlist)
                            selectedSetlist = newSetlist
                            showingEditSetlist = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Список всех сетлистов
                    List {
                        ForEach(setlists) { setlist in
                            Button(action: {
                                selectedSetlist = setlist
                                calculateTotalDuration()
                            }) {
                                HStack {
                                    Text(setlist.name)
                                    Spacer()
                                    Text("\(setlist.songs.count) songs")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteSetlist)
                    }
                    
                    // Детали выбранного сетлиста
                    if let setlist = selectedSetlist {
                        VStack {
                            HStack {
                                Text(setlist.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("Total: \(formatDuration(totalDuration))")
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    showingEditSetlist = true
                                }) {
                                    Image(systemName: "pencil")
                                }
                                
                                Button(action: {
                                    exportToPDF()
                                }) {
                                    Image(systemName: "arrow.down.doc")
                                }
                                
                                Button(action: {
                                    showingRehearsalMode = true
                                }) {
                                    Image(systemName: "play.fill")
                                }
                            }
                            .padding(.horizontal)
                            
                            List {
                                ForEach(setlist.songs) { song in
                                    HStack {
                                        Text(song.title)
                                        Spacer()
                                        Text(formatDuration(song.duration))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .onMove(perform: moveSongs)
                            }
                            
                            Button("Add Song") {
                                isAddingNewSong = true
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Setlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let newSetlist = Setlist(id: UUID().uuidString, name: "New Setlist", songs: [])
                        setlists.append(newSetlist)
                        selectedSetlist = newSetlist
                        showingEditSetlist = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingNewSong) {
                AddSongView { newSong in
                    if var setlist = selectedSetlist {
                        setlist.songs.append(newSong)
                        updateSetlist(setlist)
                        calculateTotalDuration()
                    }
                }
            }
            .sheet(isPresented: $showingEditSetlist) {
                if let setlist = selectedSetlist {
                    EditSetlistView(setlist: setlist) { updatedSetlist in
                        updateSetlist(updatedSetlist)
                    }
                }
            }
            .sheet(isPresented: $showingRehearsalMode) {
                if let setlist = selectedSetlist {
                    NavigationView {
                        RehearsalModeView(setlist: setlist)
                    }
                }
            }
        }
        .onAppear {
            loadDemoData()
        }
    }
    
    func loadDemoData() {
        // Демо-данные для тестирования
        if setlists.isEmpty {
            let demoSongs1 = [
                Song(id: "1", title: "Intro", duration: 120),
                Song(id: "2", title: "Main Theme", duration: 240),
                Song(id: "3", title: "Finale", duration: 180)
            ]
            
            let demoSongs2 = [
                Song(id: "4", title: "New Song", duration: 210),
                Song(id: "5", title: "Ballad", duration: 300)
            ]
            
            let setlist1 = Setlist(id: "1", name: "Main Set", songs: demoSongs1)
            let setlist2 = Setlist(id: "2", name: "Alternative Set", songs: demoSongs2)
            
            setlists = [setlist1, setlist2]
            selectedSetlist = setlist1
            calculateTotalDuration()
        }
    }
    
    func calculateTotalDuration() {
        if let setlist = selectedSetlist {
            totalDuration = setlist.songs.reduce(0) { $0 + $1.duration }
        }
    }
    
    func updateSetlist(_ updatedSetlist: Setlist) {
        if let index = setlists.firstIndex(where: { $0.id == updatedSetlist.id }) {
            setlists[index] = updatedSetlist
            selectedSetlist = updatedSetlist
            calculateTotalDuration()
        }
    }
    
    func deleteSetlist(at offsets: IndexSet) {
        setlists.remove(atOffsets: offsets)
        if let firstSetlist = setlists.first {
            selectedSetlist = firstSetlist
            calculateTotalDuration()
        } else {
            selectedSetlist = nil
        }
    }
    
    func moveSongs(from source: IndexSet, to destination: Int) {
        if var setlist = selectedSetlist {
            setlist.songs.move(fromOffsets: source, toOffset: destination)
            updateSetlist(setlist)
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func exportToPDF() {
        guard let setlist = selectedSetlist else { return }
        
        // Получаем текущий UIViewController для отображения меню "Поделиться"
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Не удалось найти корневой контроллер")
            return
        }
        
        // Вызываем функцию из нашего экспортера
        SetlistPDFExporter.sharePDF(from: setlist, in: rootViewController)
    }
}

// Структуры для сетлистов и песен
struct Setlist: Identifiable {
    var id: String
    var name: String
    var songs: [Song]
}

struct Song: Identifiable {
    var id: String
    var title: String
    var duration: TimeInterval // в секундах
}

// Вспомогательные вью для добавления песен и редактирования сетлистов
struct AddSongView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var minutes = 0
    @State private var seconds = 0
    
    var onAdd: (Song) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Song Title", text: $title)
                
                HStack {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...30)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                }
                
                Button("Add Song") {
                    let duration = TimeInterval(minutes * 60 + seconds)
                    let newSong = Song(id: UUID().uuidString, title: title, duration: duration)
                    onAdd(newSong)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty)
            }
            .navigationTitle("Add Song")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct EditSetlistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    var setlist: Setlist
    var onSave: (Setlist) -> Void
    
    init(setlist: Setlist, onSave: @escaping (Setlist) -> Void) {
        self.setlist = setlist
        self._name = State(initialValue: setlist.name)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Setlist Name", text: $name)
                
                Button("Save Changes") {
                    var updatedSetlist = setlist
                    updatedSetlist.name = name
                    onSave(updatedSetlist)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(name.isEmpty)
            }
            .navigationTitle("Edit Setlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

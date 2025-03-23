import SwiftUI
import FirebaseFirestore

struct SetlistPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedSetlist: [String]
    @State private var availableSetlists: [Setlist] = []
    @State private var selectedSetlistId: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if availableSetlists.isEmpty {
                    VStack {
                        Text("No setlists available")
                            .font(.headline)
                            .padding()
                        
                        Text("Create a setlist in the Setlists tab first")
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Close")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                } else {
                    List {
                        ForEach(availableSetlists) { setlist in
                            Button(action: {
                                selectedSetlistId = setlist.id
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(setlist.name)
                                            .font(.headline)
                                        Text("\(setlist.songs.count) songs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedSetlistId == setlist.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    
                    Button(action: {
                        if let selectedId = selectedSetlistId,
                           let setlist = availableSetlists.first(where: { $0.id == selectedId }) {
                            selectedSetlist = setlist.songs.map { $0.title }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Apply Setlist")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedSetlistId == nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .disabled(selectedSetlistId == nil)
                    .padding(.vertical)
                }
            }
            .navigationTitle("Choose Setlist")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                fetchSetlists()
            }
        }
    }
    
    func fetchSetlists() {
        // В реальном приложении здесь был бы код загрузки сетлистов из Firebase
        // Для демонстрации используем предустановленные сетлисты
        
        // Имитация задержки загрузки
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let setlist1 = Setlist(
                id: "1",
                name: "Main Set",
                songs: [
                    Song(id: "s1", title: "Intro", duration: 120),
                    Song(id: "s2", title: "Main Theme", duration: 240),
                    Song(id: "s3", title: "Bridge", duration: 180),
                    Song(id: "s4", title: "Finale", duration: 210)
                ]
            )
            
            let setlist2 = Setlist(
                id: "2",
                name: "Acoustic Set",
                songs: [
                    Song(id: "s5", title: "Ballad", duration: 180),
                    Song(id: "s6", title: "Unplugged", duration: 200),
                    Song(id: "s7", title: "Acoustic Version", duration: 230)
                ]
            )
            
            let setlist3 = Setlist(
                id: "3",
                name: "Festival Set",
                songs: [
                    Song(id: "s8", title: "Festival Intro", duration: 90),
                    Song(id: "s9", title: "Hit Song 1", duration: 210),
                    Song(id: "s10", title: "Hit Song 2", duration: 200),
                    Song(id: "s11", title: "Festival Outro", duration: 150)
                ]
            )
            
            availableSetlists = [setlist1, setlist2, setlist3]
        }
    }
}

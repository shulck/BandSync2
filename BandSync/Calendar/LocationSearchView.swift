import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedLocation: String
    
    @State private var searchText = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Поле поиска
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                    
                    TextField("Поиск локаций", text: $searchText)
                        .padding(8)
                        .onChange(of: searchText) { _ in
                            isSearching = true
                            searchCompleter.queryFragment = searchText
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 8)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if isSearching {
                    // Индикатор загрузки
                    ProgressView()
                        .padding()
                }
                
                // Результаты поиска
                List {
                    ForEach(searchResults, id: \.self) { result in
                        Button(action: {
                            let locationString = "\(result.title), \(result.subtitle)"
                            selectedLocation = locationString
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            VStack(alignment: .leading) {
                                Text(result.title)
                                    .font(.headline)
                                Text(result.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                
                // Популярные места (оставляем для удобства пользователя)
                if searchResults.isEmpty && !isSearching {
                    VStack(alignment: .leading) {
                        Text("Популярные места")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(demoVenues, id: \.name) { venue in
                                    Button(action: {
                                        selectedLocation = venue.name
                                        presentationMode.wrappedValue.dismiss()
                                    }) {
                                        VStack {
                                            Image(systemName: venue.icon)
                                                .font(.title)
                                                .foregroundColor(.white)
                                                .frame(width: 60, height: 60)
                                                .background(venue.color)
                                                .cornerRadius(8)
                                            
                                            Text(venue.name)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                                .frame(width: 80)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Поиск локации")
            .navigationBarItems(trailing: Button("Отмена") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                setupSearchCompleter()
            }
        }
    }
    
    // Настройка поиска локаций
    func setupSearchCompleter() {
        searchCompleter.delegate = CompleterDelegate(self)
        searchCompleter.resultTypes = .address
    }
    
    // Демо-данные популярных локаций (оставляем для удобства)
    let demoVenues: [(name: String, icon: String, color: Color)] = [
        ("Atlas Concert Hall, Киев", "music.note", .blue),
        ("Stereo Plaza, Киев", "guitars", .red),
        ("Caribbean Club, Киев", "music.mic", .orange),
        ("Palace Ukraine, Киев", "building.columns", .purple),
        ("Green Theatre, Киев", "leaf", .green),
        ("Art Club, Киев", "paintpalette", .pink),
        ("Freedom Hall, Киев", "flag", .yellow)
    ]
    
    // Класс-делегат для обработки результатов поиска
    class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
        private var parent: LocationSearchView
        
        init(_ parent: LocationSearchView) {
            self.parent = parent
        }
        
        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            parent.searchResults = completer.results
            parent.isSearching = false
        }
        
        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            print("Ошибка поиска: \(error.localizedDescription)")
            parent.isSearching = false
        }
    }
}

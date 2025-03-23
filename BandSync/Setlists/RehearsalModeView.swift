import SwiftUI

struct RehearsalModeView: View {
    let setlist: Setlist
    @State private var currentSongIndex = 0
    @State private var timeElapsed: TimeInterval = 0
    @State private var isPlaying = true
    @State private var isPaused = false
    @State private var showingCompleteAlert = false
    
    // Таймер для репетиции
    @State private var timer: Timer? = nil
    
    // Вычисляемые свойства
    private var currentSong: Song? {
        guard currentSongIndex < setlist.songs.count else { return nil }
        return setlist.songs[currentSongIndex]
    }
    
    private var progressPercentage: Double {
        guard let song = currentSong else { return 0 }
        return min(timeElapsed / song.duration, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок репетиции
            Text(setlist.name)
                .font(.largeTitle)
                .bold()
                .padding(.top)
            
            Spacer()
            
            // Информация о текущей песне
            if let song = currentSong {
                VStack(spacing: 12) {
                    Text("Текущая песня:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(song.title)
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Счетчик времени
                    HStack(spacing: 20) {
                        // Прошедшее время
                        VStack {
                            Text("Прошло")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(timeElapsed))
                                .font(.system(size: 24, weight: .medium))
                                .monospacedDigit()
                        }
                        
                        // Разделитель
                        Rectangle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 1, height: 40)
                        
                        // Оставшееся время
                        VStack {
                            Text("Осталось")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(max(0, song.duration - timeElapsed)))
                                .font(.system(size: 24, weight: .medium))
                                .monospacedDigit()
                                .foregroundColor(song.duration - timeElapsed < 10 ? .red : .primary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Индикатор прогресса
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 10)
                        .padding(.horizontal)
                }
                .padding()
                
                // Предпросмотр следующей песни
                if currentSongIndex < setlist.songs.count - 1 {
                    VStack(spacing: 6) {
                        Text("Следующая:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(setlist.songs[currentSongIndex + 1].title)
                            .font(.headline)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                Text("Репетиция завершена!")
                    .font(.headline)
            }
            
            Spacer()
            
            // Кнопки управления репетицией
            HStack(spacing: 40) {
                // Кнопка предыдущей песни
                Button(action: previousSong) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(currentSongIndex > 0 ? .blue : .gray)
                }
                .disabled(currentSongIndex <= 0)
                
                // Кнопка паузы/воспроизведения
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
                
                // Кнопка следующей песни
                Button(action: nextSong) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(currentSongIndex < setlist.songs.count - 1 ? .blue : .gray)
                }
                .disabled(currentSongIndex >= setlist.songs.count - 1)
            }
            .padding(.bottom, 40)
        }
        .padding()
        .navigationTitle("Режим репетиции")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Завершить") {
                    timer?.invalidate()
                    timer = nil
                    showingCompleteAlert = true
                }
            }
        }
        .alert(isPresented: $showingCompleteAlert) {
            Alert(
                title: Text("Завершить репетицию?"),
                message: Text("Прогресс репетиции будет сброшен."),
                primaryButton: .default(Text("Продолжить репетицию")) {
                    if isPlaying {
                        startTimer()
                    }
                },
                secondaryButton: .destructive(Text("Завершить")) {
                    // Возвращаемся к предыдущему экрану
                    // Это будет обрабатываться в .onDisappear в SetlistView
                }
            )
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isPlaying {
                timeElapsed += 0.1
                
                // Проверяем, не истекло ли время для текущей песни
                if let song = currentSong, timeElapsed >= song.duration {
                    // Автоматически переходим к следующей песне
                    if currentSongIndex < setlist.songs.count - 1 {
                        currentSongIndex += 1
                        timeElapsed = 0
                    } else {
                        // Последняя песня завершена
                        isPlaying = false
                        timer?.invalidate()
                        timer = nil
                    }
                }
            }
        }
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            timer?.invalidate()
        }
    }
    
    private func nextSong() {
        if currentSongIndex < setlist.songs.count - 1 {
            currentSongIndex += 1
            timeElapsed = 0
        }
    }
    
    private func previousSong() {
        if currentSongIndex > 0 {
            currentSongIndex -= 1
            timeElapsed = 0
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

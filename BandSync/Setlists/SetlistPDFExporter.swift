import UIKit
import PDFKit

class SetlistPDFExporter {
    // Метод для создания PDF из сетлиста
    static func createPDF(from setlist: Setlist) -> Data? {
        // Задаем размер страницы (8.5x11 дюймов)
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        // Создаем PDF renderer
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        // Генерируем PDF
        let pdfData = renderer.pdfData { context in
            // Создаем страницу
            context.beginPage()
            
            // Устанавливаем шрифты
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let headerFont = UIFont.boldSystemFont(ofSize: 14)
            let textFont = UIFont.systemFont(ofSize: 12)
            
            // Отступы
            let margin: CGFloat = 50
            var yPosition: CGFloat = margin
            
            // Рисуем заголовок сетлиста
            let title = setlist.name
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            
            let titleString = NSAttributedString(string: title, attributes: titleAttributes)
            let titleStringSize = titleString.size()
            let titleRect = CGRect(
                x: (pageWidth - titleStringSize.width) / 2.0,
                y: yPosition,
                width: titleStringSize.width,
                height: titleStringSize.height
            )
            
            titleString.draw(in: titleRect)
            
            yPosition += titleStringSize.height + 20
            
            // Рисуем общую информацию (кол-во песен, длительность)
            let totalDuration = setlist.songs.reduce(0) { $0 + $1.duration }
            let minutes = Int(totalDuration) / 60
            let seconds = Int(totalDuration) % 60
            
            let infoText = "Всего песен: \(setlist.songs.count) - Длительность: \(minutes):\(String(format: "%02d", seconds))"
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ]
            
            let infoString = NSAttributedString(string: infoText, attributes: infoAttributes)
            infoString.draw(at: CGPoint(x: margin, y: yPosition))
            
            yPosition += infoString.size().height + 15
            
            // Рисуем разделительную линию
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.move(to: CGPoint(x: margin, y: yPosition))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            context.cgContext.strokePath()
            
            yPosition += 15
            
            // Рисуем заголовки таблицы
            let headerText = "№    Название песни                                                         Время"
            let headerString = NSAttributedString(string: headerText, attributes: infoAttributes)
            headerString.draw(at: CGPoint(x: margin, y: yPosition))
            
            yPosition += headerString.size().height + 5
            
            // Рисуем каждую песню
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor.black
            ]
            
            for (index, song) in setlist.songs.enumerated() {
                let songMinutes = Int(song.duration) / 60
                let songSeconds = Int(song.duration) % 60
                let songDurationText = String(format: "%d:%02d", songMinutes, songSeconds)
                
                // Форматируем строку с информацией о песне
                let songText = String(format: "%3d  %@ %@", index + 1, song.title, songDurationText)
                let songString = NSAttributedString(string: songText, attributes: textAttributes)
                
                songString.draw(at: CGPoint(x: margin, y: yPosition))
                
                yPosition += songString.size().height + 10
                
                // Проверяем, хватает ли места на странице для следующей песни
                if yPosition > pageHeight - margin && index < setlist.songs.count - 1 {
                    // Если нет, начинаем новую страницу
                    context.beginPage()
                    yPosition = margin
                }
            }
            
            // Добавляем дату и время создания в нижний колонтитул
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            let footerText = "Создано: \(dateFormatter.string(from: Date()))"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            
            let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
            let footerSize = footerString.size()
            
            footerString.draw(at: CGPoint(x: pageWidth - margin - footerSize.width,
                                        y: pageHeight - margin))
        }
        
        return pdfData
    }
    
    // Функция для сохранения PDF и открытия меню "Поделиться"
    static func sharePDF(from setlist: Setlist, in viewController: UIViewController) {
        guard let pdfData = createPDF(from: setlist) else {
            print("Ошибка при создании PDF")
            return
        }
        
        // Создаем временный файл
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(setlist.name.replacingOccurrences(of: " ", with: "_")).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            
            // Создаем контроллер активности для "Поделиться"
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // Устанавливаем исключения для iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                          y: viewController.view.bounds.midY,
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Показываем меню "Поделиться"
            viewController.present(activityViewController, animated: true)
        } catch {
            print("Ошибка при сохранении PDF: \(error.localizedDescription)")
        }
    }
}

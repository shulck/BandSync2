import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FinancesView: View {
    @State private var userRole: String = "Loading..."
    @State private var finances: [FinanceRecord] = []
    @State private var selectedCurrency = "USD"
    @State private var showingAddTransaction = false
    @State private var totalIncome: Double = 0
    @State private var totalExpenses: Double = 0
    @State private var selectedTimeRange: TimeRange = .month
    
    var currencies = ["USD", "EUR", "UAH"]
    
    var body: some View {
        NavigationView {
            VStack {
                if userRole == "Admin" || userRole == "Manager" {
                    // Выбор валюты
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Выбор периода времени
                    Picker("Time Range", selection: $selectedTimeRange) {
                        Text("Week").tag(TimeRange.week)
                        Text("Month").tag(TimeRange.month)
                        Text("Year").tag(TimeRange.year)
                        Text("All").tag(TimeRange.all)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Финансовая сводка
                    FinanceSummaryView(totalIncome: totalIncome, totalExpenses: totalExpenses, currency: selectedCurrency)
                        .padding()
                    
                    // График доходы/расходы
                    FinanceChartView(finances: finances)
                        .frame(height: 200)
                        .padding(.horizontal)
                    
                    // Список транзакций
                    List {
                        ForEach(finances) { record in
                            HStack {
                                Image(systemName: record.type == .income ? "arrow.down" : "arrow.up")
                                    .foregroundColor(record.type == .income ? .green : .red)
                                
                                VStack(alignment: .leading) {
                                    Text(record.description)
                                    Text(record.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(formatCurrency(amount: record.amount, currency: record.currency))
                                    .foregroundColor(record.type == .income ? .green : .red)
                            }
                        }
                        .onDelete(perform: deleteRecord)
                    }
                    
                    Button(action: {
                        showingAddTransaction = true
                    }) {
                        Text("Add Transaction")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                } else {
                    Text(LocalizedStringKey("no_access"))
                        .foregroundColor(.red)
                        .font(.title)
                }
            }
            .navigationTitle("Finances")
            .onAppear {
                fetchUserRole()
                fetchFinances()
            }
            .onChange(of: selectedTimeRange) { _ in
                calculateTotals()
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddFinanceRecordView { newRecord in
                    finances.append(newRecord)
                    saveFinanceRecord(newRecord)
                    calculateTotals()
                }
            }
        }
    }
    
    func calculateTotals() {
        let filteredRecords = filterRecordsByTimeRange(finances)
        totalIncome = filteredRecords.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        totalExpenses = filteredRecords.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    func filterRecordsByTimeRange(_ records: [FinanceRecord]) -> [FinanceRecord] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return records.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return records.filter { $0.date >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return records.filter { $0.date >= yearAgo }
        case .all:
            return records
        }
    }
    
    func formatCurrency(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
    
    func deleteRecord(at offsets: IndexSet) {
        // Получаем ID записей, которые нужно удалить
        let recordsToDelete = offsets.map { finances[$0] }
        
        // Удаляем из Firebase
        let db = Firestore.firestore()
        recordsToDelete.forEach { record in
            db.collection("finances").document(record.id).delete { error in
                if let error = error {
                    print("Error deleting record: \(error.localizedDescription)")
                }
            }
        }
        
        // Удаляем из локального массива
        finances.remove(atOffsets: offsets)
        calculateTotals()
    }

    func fetchUserRole() {
        guard let user = Auth.auth().currentUser else {
            userRole = LocalizedStringKey("not_authorized").toString()
            return
        }

        let db = Firestore.firestore()
        db.collection("users").whereField("email", isEqualTo: user.email ?? "").getDocuments { snapshot, error in
            if let snapshot = snapshot, let document = snapshot.documents.first {
                self.userRole = document.data()["role"] as? String ?? LocalizedStringKey("unknown_role").toString()
            } else {
                self.userRole = LocalizedStringKey("error_loading").toString()
            }
        }
    }
    
    func fetchFinances() {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        db.collection("finances")
            .whereField("userId", isEqualTo: user.uid)
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching finances: \(error.localizedDescription)")
                    return
                }
                
                if let snapshot = snapshot {
                    self.finances = snapshot.documents.compactMap { document -> FinanceRecord? in
                        let data = document.data()
                        
                        guard let typeString = data["type"] as? String,
                              let amount = data["amount"] as? Double,
                              let currency = data["currency"] as? String,
                              let description = data["description"] as? String,
                              let category = data["category"] as? String,
                              let timestamp = data["date"] as? Timestamp else {
                            return nil
                        }
                        
                        let type: FinanceType = typeString == "income" ? .income : .expense
                        let date = timestamp.dateValue()
                        let receiptImageURL = data["receiptImageURL"] as? String
                        
                        return FinanceRecord(
                            id: document.documentID,
                            type: type,
                            amount: amount,
                            currency: currency,
                            description: description,
                            category: category,
                            date: date,
                            receiptImageURL: receiptImageURL
                        )
                    }
                    
                    // Если данных нет, загружаем демо-данные
                    if self.finances.isEmpty {
                        self.loadDemoData()
                    }
                    
                    self.calculateTotals()
                }
            }
    }
    
    func loadDemoData() {
        let now = Date()
        let calendar = Calendar.current
        
        let demoData: [FinanceRecord] = [
            FinanceRecord(id: "1", type: .income, amount: 1200, currency: "USD", description: "Concert at Club X", category: "Gig", date: now),
            FinanceRecord(id: "2", type: .expense, amount: 300, currency: "USD", description: "Transportation", category: "Logistics", date: calendar.date(byAdding: .day, value: -2, to: now)!),
            FinanceRecord(id: "3", type: .expense, amount: 180, currency: "USD", description: "Hotel", category: "Accommodation", date: calendar.date(byAdding: .day, value: -2, to: now)!),
            FinanceRecord(id: "4", type: .income, amount: 950, currency: "USD", description: "Festival Performance", category: "Gig", date: calendar.date(byAdding: .day, value: -10, to: now)!),
            FinanceRecord(id: "5", type: .expense, amount: 120, currency: "USD", description: "Equipment Rental", category: "Equipment", date: calendar.date(byAdding: .day, value: -12, to: now)!),
            FinanceRecord(id: "6", type: .income, amount: 350, currency: "USD", description: "Merchandise Sales", category: "Merchandise", date: calendar.date(byAdding: .day, value: -15, to: now)!)
        ]
        
        finances = demoData
    }
    
    func saveFinanceRecord(_ record: FinanceRecord) {
        guard let user = Auth.auth().currentUser else { return }
        
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "userId": user.uid,
            "type": record.type == .income ? "income" : "expense",
            "amount": record.amount,
            "currency": record.currency,
            "description": record.description,
            "category": record.category,
            "date": Timestamp(date: record.date)
        ]
        
        if let receiptImageURL = record.receiptImageURL {
            data["receiptImageURL"] = receiptImageURL
        }
        
        db.collection("finances").document(record.id).setData(data) { error in
            if let error = error {
                print("Error saving finance record: \(error.localizedDescription)")
            }
        }
    }
}

// Временной диапазон для фильтрации данных
enum TimeRange {
    case week, month, year, all
}

// Тип финансовой операции
enum FinanceType {
    case income, expense
}

// Структура финансовой записи
struct FinanceRecord: Identifiable {
    var id: String
    var type: FinanceType
    var amount: Double
    var currency: String
    var description: String
    var category: String
    var date: Date
    var receiptImageURL: String?
}

// Представление для отображения финансовой сводки
struct FinanceSummaryView: View {
    var totalIncome: Double
    var totalExpenses: Double
    var currency: String
    
    var profit: Double {
        totalIncome - totalExpenses
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 20) {
                VStack {
                    Text("Income")
                        .font(.headline)
                    Text(formatCurrency(amount: totalIncome, currency: currency))
                        .foregroundColor(.green)
                }
                
                Divider()
                
                VStack {
                    Text("Expenses")
                        .font(.headline)
                    Text(formatCurrency(amount: totalExpenses, currency: currency))
                        .foregroundColor(.red)
                }
                
                Divider()
                
                VStack {
                    Text("Profit")
                        .font(.headline)
                    Text(formatCurrency(amount: profit, currency: currency))
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    func formatCurrency(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}

// График доходов и расходов
struct FinanceChartView: View {
    var finances: [FinanceRecord]
    
    // Подготовка данных для графика
    var chartData: [(date: Date, income: Double, expense: Double)] {
        // Группировка записей по дате (день)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var groupedData: [String: (income: Double, expense: Double)] = [:]
        
        // Инициализируем данные за последние 7 дней
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateString = dateFormatter.string(from: date)
                groupedData[dateString] = (0, 0)
            }
        }
        
        // Суммируем доходы и расходы за каждый день
        for record in finances {
            let dateString = dateFormatter.string(from: record.date)
            
            var existingData = groupedData[dateString] ?? (0, 0)
            
            if record.type == .income {
                existingData.income += record.amount
            } else {
                existingData.expense += record.amount
            }
            
            groupedData[dateString] = existingData
        }
        
        // Преобразуем в массив для графика, сортируя по дате
        return groupedData.map { (dateString, values) -> (date: Date, income: Double, expense: Double) in
            let date = dateFormatter.date(from: dateString) ?? Date()
            return (date, values.income, values.expense)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack {
            // Реализация графика с использованием SwiftUI
            // В реальном приложении здесь будет использована библиотека Charts
            HStack(alignment: .bottom, spacing: 15) {
                ForEach(chartData, id: \.date) { dataPoint in
                    VStack(spacing: 4) {
                        Text(formatDate(dataPoint.date))
                            .font(.caption)
                            .rotationEffect(.degrees(-45))
                            .frame(width: 30)
                        
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 15, height: scaledHeight(dataPoint.income))
                            
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 15, height: scaledHeight(dataPoint.expense))
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(.top, 20)
            
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Income")
                    .font(.caption)
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("Expense")
                    .font(.caption)
            }
        }
    }
    
    // Helper для масштабирования высоты столбцов
    func scaledHeight(_ value: Double) -> CGFloat {
        let maxValue = chartData.flatMap { [$0.income, $0.expense] }.max() ?? 1
        let scale = 150.0 / maxValue
        return CGFloat(value * scale)
    }
    
    // Helper для форматирования даты
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

// Представление для добавления финансовой записи
struct AddFinanceRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var transactionType: FinanceType = .income
    @State private var amount = ""
    @State private var description = ""
    @State private var category = ""
    @State private var currency = "USD"
    @State private var date = Date()
    @State private var showImagePicker = false
    @State private var receiptImage: UIImage?
    
    var currencies = ["USD", "EUR", "UAH"]
    
    var incomeCategories = ["Gig", "Merchandise", "Royalties", "Sponsorship", "Other"]
    var expenseCategories = ["Logistics", "Accommodation", "Food", "Equipment", "Promotion", "Fees", "Other"]
    
    var onAdd: (FinanceRecord) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transaction Type")) {
                    Picker("Type", selection: $transactionType) {
                        Text("Income").tag(FinanceType.income)
                        Text("Expense").tag(FinanceType.expense)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Details")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    
                    TextField("Description", text: $description)
                    
                    Picker("Category", selection: $category) {
                        ForEach(transactionType == .income ? incomeCategories : expenseCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Receipt/Invoice")) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Text(receiptImage == nil ? "Add Receipt Image" : "Change Receipt Image")
                            Spacer()
                            if receiptImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if receiptImage != nil {
                        Image(uiImage: receiptImage!)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }
                
                Section {
                    Button("Save Transaction") {
                        saveTransaction()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showImagePicker) {
                // В реальном приложении здесь был бы ImagePicker
                Text("Image Picker would be here")
            }
            .onChange(of: transactionType) { _ in
                // Сбрасываем категорию при смене типа транзакции
                category = ""
            }
        }
    }
    
    var isFormValid: Bool {
        let amountValue = Double(amount) ?? 0
        return !description.isEmpty && !category.isEmpty && amountValue > 0
    }
    
    func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        // В реальном приложении здесь был бы код для загрузки изображения
        // и получения URL для сохранения
        let receiptURL: String? = receiptImage != nil ? "https://example.com/receipts/demo-receipt.jpg" : nil
        
        let newRecord = FinanceRecord(
            id: UUID().uuidString,
            type: transactionType,
            amount: amountValue,
            currency: currency,
            description: description,
            category: category,
            date: date,
            receiptImageURL: receiptURL
        )
        
        onAdd(newRecord)
        presentationMode.wrappedValue.dismiss()
    }
}

// Расширение для преобразования LocalizedStringKey в String
extension LocalizedStringKey {
    func toString() -> String {
        // Это упрощенная реализация, которая работает только для простых случаев
        // В реальном приложении следует использовать NSLocalizedString или другой механизм
        switch self {
        case "no_access": return "No Access"
        case "not_authorized": return "Not Authorized"
        case "unknown_role": return "Unknown Role"
        case "error_loading": return "Error Loading"
        default: return "Unknown"
        }
    }
}

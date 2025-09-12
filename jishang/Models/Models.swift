//
//  Models.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import Foundation
import SwiftUI

// MARK: - Currency Formatting Extension
extension Double {
    var currencyFormatted: String {
        return String(format: "¥%.2f", self)
    }
    
    var currencyFormattedWithSign: String {
        let sign = self >= 0 ? "+" : "-"
        return String(format: "%@¥%.2f", sign, abs(self))
    }
}

enum TransactionType: String, CaseIterable, Codable, Identifiable {
    case income = "income"
    case expense = "expense"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .income:
            return .green
        case .expense:
            return .red
        }
    }
}

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let defaultType: TransactionType
    let isCustom: Bool
    
    init(id: UUID = UUID(), name: String, icon: String, defaultType: TransactionType, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.defaultType = defaultType
        self.isCustom = isCustom
    }
    
    var rawValue: String {
        return name
    }
    
    // 使用稳定的、跨版本一致的 UUID，避免每次安装随机生成导致的匹配失败
    private static let predefinedIDs: [String: String] = [
        "餐饮": "11111111-1111-1111-1111-111111111111",
        "交通": "22222222-2222-2222-2222-222222222222",
        "购物": "33333333-3333-3333-3333-333333333333",
        "娱乐": "44444444-4444-4444-4444-444444444444",
        "医疗": "55555555-5555-5555-5555-555555555555",
        "教育": "66666666-6666-6666-6666-666666666666",
        "住房": "77777777-7777-7777-7777-777777777777",
        "工资": "88888888-8888-8888-8888-888888888888",
        "奖金": "99999999-9999-9999-9999-999999999999",
        "投资": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "其他": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    ]

    private static func stableId(for name: String) -> UUID {
        if let s = predefinedIDs[name], let u = UUID(uuidString: s) { return u }
        return UUID()
    }

    static let predefinedCategories: [Category] = [
        Category(id: stableId(for: "餐饮"), name: "餐饮", icon: "🍽️", defaultType: .expense),
        Category(id: stableId(for: "交通"), name: "交通", icon: "🚗", defaultType: .expense),
        Category(id: stableId(for: "购物"), name: "购物", icon: "🛍️", defaultType: .expense),
        Category(id: stableId(for: "娱乐"), name: "娱乐", icon: "🎬", defaultType: .expense),
        Category(id: stableId(for: "医疗"), name: "医疗", icon: "🏥", defaultType: .expense),
        Category(id: stableId(for: "教育"), name: "教育", icon: "📚", defaultType: .expense),
        Category(id: stableId(for: "住房"), name: "住房", icon: "🏠", defaultType: .expense),
        Category(id: stableId(for: "工资"), name: "工资", icon: "💼", defaultType: .income),
        Category(id: stableId(for: "奖金"), name: "奖金", icon: "🎁", defaultType: .income),
        Category(id: stableId(for: "投资"), name: "投资", icon: "📈", defaultType: .income),
        Category(id: stableId(for: "其他"), name: "其他", icon: "📝", defaultType: .expense)
    ]
    
    // 为了保持向后兼容性，提供一些便捷的静态属性
    static let food = predefinedCategories[0]
    static let transport = predefinedCategories[1]
    static let shopping = predefinedCategories[2]
    static let entertainment = predefinedCategories[3]
    static let healthcare = predefinedCategories[4]
    static let education = predefinedCategories[5]
    static let housing = predefinedCategories[6]
    static let salary = predefinedCategories[7]
    static let bonus = predefinedCategories[8]
    static let investment = predefinedCategories[9]
    static let other = predefinedCategories[10]
}

struct Transaction: Identifiable, Codable {
    var id: UUID = UUID()
    var amount: Double
    var category: Category
    var type: TransactionType
    var date: Date
    var note: String
    
    init(amount: Double, category: Category, type: TransactionType, date: Date = Date(), note: String = "") {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.type = type
        self.date = date
        self.note = note
    }
}

enum FilterType: Equatable {
    case all
    case byTransactionType(TransactionType)
    case byCategory(Category)
    case byYear(Int)
    case byMonth(Int, Int) // year, month
    case byYearAndTransactionType(Int, TransactionType)
    case byMonthAndTransactionType(Int, Int, TransactionType) // year, month, type
    case byYearAndCategory(Int, Category)
    case byMonthAndCategory(Int, Int, Category) // year, month, category
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .byTransactionType(let type):
            return type == .income ? "收入" : "支出"
        case .byCategory(let category):
            return category.rawValue
        case .byYear(let year):
            return "\(String(format: "%d", year))年"
        case .byMonth(let year, let month):
            return "\(String(format: "%d", year))年\(month)月"
        case .byYearAndTransactionType(let year, let type):
            return "\(String(format: "%d", year))年 - \(type == .income ? "收入" : "支出")"
        case .byMonthAndTransactionType(let year, let month, let type):
            return "\(String(format: "%d", year))年\(month)月 - \(type == .income ? "收入" : "支出")"
        case .byYearAndCategory(let year, let category):
            return "\(String(format: "%d", year))年 - \(category.rawValue)"
        case .byMonthAndCategory(let year, let month, let category):
            return "\(String(format: "%d", year))年\(month)月 - \(category.rawValue)"
        }
    }
    
    static var predefinedFilters: [FilterType] {
        return [
            .all,
            .byTransactionType(.income),
            .byTransactionType(.expense)
        ]
    }
    
    static func categoryFilters(from categories: [Category]) -> [FilterType] {
        return categories.map { .byCategory($0) }
    }
    
    static func allFilters(from categories: [Category]) -> [FilterType] {
        return predefinedFilters + categoryFilters(from: categories)
    }
    
    func matches(transaction: Transaction) -> Bool {
        let calendar = Calendar.current
        let transactionYear = calendar.component(.year, from: transaction.date)
        let transactionMonth = calendar.component(.month, from: transaction.date)
        
        switch self {
        case .all:
            return true
        case .byTransactionType(let type):
            return transaction.type == type
        case .byCategory(let category):
            return transaction.category == category
        case .byYear(let year):
            return transactionYear == year
        case .byMonth(let year, let month):
            return transactionYear == year && transactionMonth == month
        case .byYearAndTransactionType(let year, let type):
            return transactionYear == year && transaction.type == type
        case .byMonthAndTransactionType(let year, let month, let type):
            return transactionYear == year && transactionMonth == month && transaction.type == type
        case .byYearAndCategory(let year, let category):
            return transactionYear == year && transaction.category == category
        case .byMonthAndCategory(let year, let month, let category):
            return transactionYear == year && transactionMonth == month && transaction.category == category
        }
    }
}

class TransactionStore: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var customCategories: [Category] = []
    
    private let transactionsFileName = "transactions.json"
    private let categoriesFileName = "custom_categories.json"
    
    var allCategories: [Category] {
        return Category.predefinedCategories + customCategories
    }
    
    var allFilters: [FilterType] {
        return FilterType.allFilters(from: allCategories)
    }
    
    init() {
        loadPersistedData()
        // 迁移：将交易中的预置分类标准化为稳定ID，避免跨版本丢失映射
        normalizePredefinedCategoriesInTransactions()
    }
    
    // MARK: - Persistence Methods
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var transactionsURL: URL {
        documentsDirectory.appendingPathComponent(transactionsFileName)
    }
    
    private var categoriesURL: URL {
        documentsDirectory.appendingPathComponent(categoriesFileName)
    }
    
    private func loadPersistedData() {
        loadTransactions()
        loadCustomCategories()
        
        // 如果没有持久化数据，加载示例数据
        if transactions.isEmpty {
            loadSampleData()
            saveData() // 保存示例数据
        }
    }
    
    private func loadTransactions() {
        do {
            let data = try Data(contentsOf: transactionsURL)
            transactions = try JSONDecoder().decode([Transaction].self, from: data)
            print("✅ 成功加载 \(transactions.count) 条交易记录")
        } catch {
            print("⚠️ 加载交易记录失败: \(error)")
            transactions = []
        }
    }
    
    private func loadCustomCategories() {
        do {
            let data = try Data(contentsOf: categoriesURL)
            customCategories = try JSONDecoder().decode([Category].self, from: data)
            print("✅ 成功加载 \(customCategories.count) 个自定义分类")
        } catch {
            print("⚠️ 加载自定义分类失败: \(error)")
            customCategories = []
        }
    }
    
    private func saveTransactions() {
        do {
            let data = try JSONEncoder().encode(transactions)
            try data.write(to: transactionsURL)
            print("✅ 成功保存 \(transactions.count) 条交易记录")
        } catch {
            print("❌ 保存交易记录失败: \(error)")
        }
    }
    
    private func saveCustomCategories() {
        do {
            let data = try JSONEncoder().encode(customCategories)
            try data.write(to: categoriesURL)
            print("✅ 成功保存 \(customCategories.count) 个自定义分类")
        } catch {
            print("❌ 保存自定义分类失败: \(error)")
        }
    }
    
    private func saveData() {
        saveTransactions()
        saveCustomCategories()
    }

    // 将旧版本中使用的随机ID预置分类，映射为当前版本的稳定ID对象（按名称匹配）
    private func normalizePredefinedCategoriesInTransactions() {
        var changed = false
        for i in transactions.indices {
            let t = transactions[i]
            // 仅处理非自定义分类
            if !t.category.isCustom {
                if let canonical = Category.predefinedCategories.first(where: { $0.name == t.category.name && $0.defaultType == t.category.defaultType }) {
                    if t.category.id != canonical.id {
                        transactions[i].category = canonical
                        changed = true
                    }
                }
            }
        }
        if changed {
            saveTransactions()
        }
    }
    
    // MARK: - Public Methods for External Saving
    
    /// 手动保存所有数据
    func saveAllData() {
        saveData()
    }
    
    /// 清除所有数据（用于测试或重置）
    func clearAllData() {
        transactions.removeAll()
        customCategories.removeAll()
        
        // 删除本地文件
        try? FileManager.default.removeItem(at: transactionsURL)
        try? FileManager.default.removeItem(at: categoriesURL)
        
        print("✅ 已清除所有数据")
    }
    
    func addCustomCategory(name: String, icon: String, defaultType: TransactionType) {
        let newCategory = Category(
            name: name,
            icon: icon,
            defaultType: defaultType,
            isCustom: true
        )
        customCategories.append(newCategory)
        saveCustomCategories()
    }
    
    func removeCustomCategory(_ category: Category) {
        customCategories.removeAll { $0.id == category.id }
        saveCustomCategories()
    }

    /// 删除自定义分类，并将该分类下的所有交易的分类置为空（不删除交易）。
    /// 空分类通过创建一个名称与图标均为空字符串的占位分类来表示，按交易本身的类型分别生成收入/支出的占位分类。
    func deleteCategoryAndReassign(_ category: Category) {
        // 仅允许删除自定义分类，预置分类忽略
        guard category.isCustom else { return }

        // 从自定义分类中移除
        customCategories.removeAll { $0.id == category.id }
        saveCustomCategories()

        // 将所有属于该分类的交易，分类置为空（按交易类型生成占位类别）
        for i in transactions.indices {
            if transactions[i].category.id == category.id {
                let placeholder = Category(name: "", icon: "", defaultType: transactions[i].type, isCustom: true)
                transactions[i].category = placeholder
            }
        }
        saveTransactions()
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
        let today = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
        
        transactions = [
            // Current month transactions
            Transaction(amount: 5000, category: .salary, type: .income, date: calendar.date(byAdding: .day, value: -1, to: today)!, note: "月薪"),
            Transaction(amount: 1000, category: .bonus, type: .income, date: calendar.date(byAdding: .day, value: -5, to: today)!, note: "绩效奖金"),
            Transaction(amount: 2500, category: .investment, type: .income, date: calendar.date(byAdding: .day, value: -10, to: today)!, note: "股票收益"),
            Transaction(amount: 800, category: .other, type: .expense, date: calendar.date(byAdding: .day, value: -15, to: today)!, note: "其他购买"),
            Transaction(amount: 35.5, category: .food, type: .expense, date: calendar.date(byAdding: .day, value: -1, to: today)!, note: "午餐"),
            Transaction(amount: 120, category: .transport, type: .expense, date: calendar.date(byAdding: .day, value: -2, to: today)!, note: "打车费"),
            Transaction(amount: 299, category: .shopping, type: .expense, date: calendar.date(byAdding: .day, value: -3, to: today)!, note: "购买衣服"),
            Transaction(amount: 88, category: .entertainment, type: .expense, date: calendar.date(byAdding: .day, value: -7, to: today)!, note: "电影票"),
            Transaction(amount: 450, category: .healthcare, type: .expense, date: calendar.date(byAdding: .day, value: -12, to: today)!, note: "体检费用"),
            Transaction(amount: 1200, category: .housing, type: .expense, date: calendar.date(byAdding: .day, value: -20, to: today)!, note: "房租"),
            
            // Last month transactions for comparison
            Transaction(amount: 4800, category: .salary, type: .income, date: calendar.date(byAdding: .day, value: -5, to: lastMonth)!, note: "上月月薪"),
            Transaction(amount: 800, category: .bonus, type: .income, date: calendar.date(byAdding: .day, value: -10, to: lastMonth)!, note: "上月奖金"),
            Transaction(amount: 1500, category: .investment, type: .income, date: calendar.date(byAdding: .day, value: -15, to: lastMonth)!, note: "上月投资收益"),
            Transaction(amount: 42.8, category: .food, type: .expense, date: calendar.date(byAdding: .day, value: -3, to: lastMonth)!, note: "上月餐饮"),
            Transaction(amount: 95, category: .transport, type: .expense, date: calendar.date(byAdding: .day, value: -6, to: lastMonth)!, note: "上月交通"),
            Transaction(amount: 350, category: .shopping, type: .expense, date: calendar.date(byAdding: .day, value: -8, to: lastMonth)!, note: "上月购物"),
            Transaction(amount: 120, category: .entertainment, type: .expense, date: calendar.date(byAdding: .day, value: -12, to: lastMonth)!, note: "上月娱乐"),
            Transaction(amount: 1200, category: .housing, type: .expense, date: calendar.date(byAdding: .day, value: -25, to: lastMonth)!, note: "上月房租")
        ]
    }
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        saveTransactions()
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            saveTransactions()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveTransactions()
    }
    
    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    var balance: Double {
        totalIncome - totalExpense
    }
    
    func monthlyIncome(for date: Date) -> Double {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: date, toGranularity: .month) && transaction.type == .income
        }.reduce(0) { $0 + $1.amount }
    }
    
    func monthlyExpense(for date: Date) -> Double {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: date, toGranularity: .month) && transaction.type == .expense
        }.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Date-based filtering helpers
    
    /// 获取所有交易中包含的年份，按降序排列
    var availableYears: [Int] {
        let calendar = Calendar.current
        let years = Set(transactions.map { calendar.component(.year, from: $0.date) })
        return Array(years).sorted(by: >)
    }
    
    /// 获取指定年份中包含的月份，按升序排列
    func availableMonths(for year: Int) -> [Int] {
        let calendar = Calendar.current
        let months = Set(transactions.compactMap { transaction in
            let transactionYear = calendar.component(.year, from: transaction.date)
            if transactionYear == year {
                return calendar.component(.month, from: transaction.date)
            }
            return nil
        })
        return Array(months).sorted()
    }
    
    /// 获取所有交易中包含的年月组合，按降序排列
    var availableYearMonths: [(year: Int, month: Int)] {
        let calendar = Calendar.current
        
        // 使用字典来去重，key 是 "year-month" 的字符串格式
        var yearMonthDict: [String: (year: Int, month: Int)] = [:]
        
        for transaction in transactions {
            let year = calendar.component(.year, from: transaction.date)
            let month = calendar.component(.month, from: transaction.date)
            let key = "\(year)-\(month)"
            yearMonthDict[key] = (year: year, month: month)
        }
        
        return Array(yearMonthDict.values).sorted { first, second in
            if first.year != second.year {
                return first.year > second.year
            }
            return first.month > second.month
        }
    }
}

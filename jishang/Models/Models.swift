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
    
    static let predefinedCategories: [Category] = [
        Category(name: "餐饮", icon: "🍽️", defaultType: .expense),
        Category(name: "交通", icon: "🚗", defaultType: .expense),
        Category(name: "购物", icon: "🛍️", defaultType: .expense),
        Category(name: "娱乐", icon: "🎬", defaultType: .expense),
        Category(name: "医疗", icon: "🏥", defaultType: .expense),
        Category(name: "教育", icon: "📚", defaultType: .expense),
        Category(name: "住房", icon: "🏠", defaultType: .expense),
        Category(name: "工资", icon: "💼", defaultType: .income),
        Category(name: "奖金", icon: "🎁", defaultType: .income),
        Category(name: "投资", icon: "📈", defaultType: .income),
        Category(name: "其他", icon: "📝", defaultType: .expense)
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
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .byTransactionType(let type):
            return type == .income ? "收入" : "支出"
        case .byCategory(let category):
            return category.rawValue
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
        switch self {
        case .all:
            return true
        case .byTransactionType(let type):
            return transaction.type == type
        case .byCategory(let category):
            return transaction.category == category
        }
    }
}

class TransactionStore: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var customCategories: [Category] = []
    
    var allCategories: [Category] {
        return Category.predefinedCategories + customCategories
    }
    
    var allFilters: [FilterType] {
        return FilterType.allFilters(from: allCategories)
    }
    
    init() {
        loadSampleData()
    }
    
    func addCustomCategory(name: String, icon: String, defaultType: TransactionType) {
        let newCategory = Category(
            name: name,
            icon: icon,
            defaultType: defaultType,
            isCustom: true
        )
        customCategories.append(newCategory)
    }
    
    func removeCustomCategory(_ category: Category) {
        customCategories.removeAll { $0.id == category.id }
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
        let today = Date()
        
        transactions = [
            Transaction(amount: 5000, category: .salary, type: .income, date: calendar.date(byAdding: .day, value: -1, to: today)!, note: "月薪"),
            Transaction(amount: 1000, category: .bonus, type: .income, date: calendar.date(byAdding: .day, value: -5, to: today)!, note: "绩效奖金"),
            Transaction(amount: 2500, category: .investment, type: .income, date: calendar.date(byAdding: .day, value: -10, to: today)!, note: "股票收益"),
            Transaction(amount: 800, category: .other, type: .income, date: calendar.date(byAdding: .day, value: -15, to: today)!, note: "兼职收入"),
            Transaction(amount: 35.5, category: .food, type: .expense, date: calendar.date(byAdding: .day, value: -1, to: today)!, note: "午餐"),
            Transaction(amount: 120, category: .transport, type: .expense, date: calendar.date(byAdding: .day, value: -2, to: today)!, note: "打车费"),
            Transaction(amount: 299, category: .shopping, type: .expense, date: calendar.date(byAdding: .day, value: -3, to: today)!, note: "购买衣服"),
            Transaction(amount: 88, category: .entertainment, type: .expense, date: calendar.date(byAdding: .day, value: -7, to: today)!, note: "电影票"),
            Transaction(amount: 450, category: .healthcare, type: .expense, date: calendar.date(byAdding: .day, value: -12, to: today)!, note: "体检费用"),
            Transaction(amount: 1200, category: .housing, type: .expense, date: calendar.date(byAdding: .day, value: -20, to: today)!, note: "房租")
        ]
    }
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
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
}

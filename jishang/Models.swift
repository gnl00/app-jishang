//
//  Models.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import Foundation
import SwiftUI

enum TransactionType: String, CaseIterable, Codable {
    case income = "income"
    case expense = "expense"
    
    var color: Color {
        switch self {
        case .income:
            return .green
        case .expense:
            return .red
        }
    }
}

enum Category: String, CaseIterable, Codable {
    case food = "餐饮"
    case transport = "交通"
    case shopping = "购物"
    case entertainment = "娱乐"
    case healthcare = "医疗"
    case education = "教育"
    case housing = "住房"
    case salary = "工资"
    case bonus = "奖金"
    case investment = "投资"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .food: return "🍽️"
        case .transport: return "🚗"
        case .shopping: return "🛍️"
        case .entertainment: return "🎬"
        case .healthcare: return "🏥"
        case .education: return "📚"
        case .housing: return "🏠"
        case .salary: return "💼"
        case .bonus: return "🎁"
        case .investment: return "📈"
        case .other: return "📝"
        }
    }
    
    var defaultType: TransactionType {
        switch self {
        case .salary, .bonus, .investment:
            return .income
        default:
            return .expense
        }
    }
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

enum FilterCategory: String, CaseIterable {
    case all = "全部"
    case income = "收入"
    case expense = "支出"
}

class TransactionStore: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        let calendar = Calendar.current
        let today = Date()
        
        transactions = [
            Transaction(amount: 5000, category: .salary, type: .income, date: calendar.date(byAdding: .day, value: -1, to: today)!, note: "月薪"),
            Transaction(amount: 35.5, category: .food, type: .expense, date: calendar.date(byAdding: .day, value: -1, to: today)!, note: "午餐"),
            Transaction(amount: 120, category: .transport, type: .expense, date: calendar.date(byAdding: .day, value: -2, to: today)!, note: "打车费"),
            Transaction(amount: 299, category: .shopping, type: .expense, date: calendar.date(byAdding: .day, value: -3, to: today)!, note: "购买衣服"),
            Transaction(amount: 1000, category: .bonus, type: .income, date: calendar.date(byAdding: .day, value: -5, to: today)!, note: "绩效奖金"),
            Transaction(amount: 88, category: .entertainment, type: .expense, date: calendar.date(byAdding: .day, value: -7, to: today)!, note: "电影票")
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

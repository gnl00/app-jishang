//
//  PieChartView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct CategoryData: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Double
    let color: Color
    
    init(category: Category, amount: Double, color: Color) {
        self.category = category
        self.amount = amount
        self.color = color
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(center: center,
                   radius: radius,
                   startAngle: startAngle,
                   endAngle: endAngle,
                   clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

struct PieChart: View {
    let data: [CategoryData]
    let size: CGFloat
    
    private var total: Double {
        data.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, categoryData in
                let startAngle = calculateStartAngle(for: index)
                let endAngle = calculateEndAngle(for: index)
                
                PieSlice(startAngle: startAngle, endAngle: endAngle)
                    .fill(categoryData.color)
                    .overlay(
                        PieSlice(startAngle: startAngle, endAngle: endAngle)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
        }
        .frame(width: size, height: size)
    }
    
    private func calculateStartAngle(for index: Int) -> Angle {
        let previousTotal = data.prefix(index).reduce(0) { $0 + $1.amount }
        return Angle(degrees: (previousTotal / total) * 360 - 90)
    }
    
    private func calculateEndAngle(for index: Int) -> Angle {
        let currentTotal = data.prefix(index + 1).reduce(0) { $0 + $1.amount }
        return Angle(degrees: (currentTotal / total) * 360 - 90)
    }
}

enum SortType: String, CaseIterable {
    case dateDesc = "时间"
    case amountDesc = "金额"
}

enum SortOrder {
    case descending  // 时间：最近, 金额：最大
    case ascending   // 时间：最早, 金额：最小
}

struct CategoryDetailPopover: View {
    let category: Category
    let transactions: [Transaction]
    @State private var sortType: SortType = .dateDesc
    @State private var sortOrder: SortOrder = .descending
    @Binding var isPresented: Bool
    
    private var sortedTransactions: [Transaction] {
        switch (sortType, sortOrder) {
        case (.dateDesc, .descending):
            return transactions.sorted { $0.date > $1.date }
        case (.dateDesc, .ascending):
            return transactions.sorted { $0.date < $1.date }
        case (.amountDesc, .descending):
            return transactions.sorted { $0.amount > $1.amount }
        case (.amountDesc, .ascending):
            return transactions.sorted { $0.amount < $1.amount }
        }
    }
    
    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    private func getSortIcon(for type: SortType) -> String {
        if sortType == type {
            switch (type, sortOrder) {
            case (.dateDesc, .descending):
                return "arrow.down" // 最近时间
            case (.dateDesc, .ascending):
                return "arrow.up"   // 最早时间
            case (.amountDesc, .descending):
                return "arrow.down" // 最大金额
            case (.amountDesc, .ascending):
                return "arrow.up"   // 最小金额
            }
        } else {
            return "arrow.up.arrow.down" // 未选中状态显示双箭头
        }
    }
    
    var body: some View {
        return NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // 顶部统计信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.icon + " " + category.name)
                            .font(.system(size: 18, weight: .semibold))
                        Text("共 \(transactions.count) 笔交易")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("总计")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(totalAmount.currencyFormatted)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(transactions.first?.type == .income ? .green : .red)
                    }
                }
                .padding(.horizontal)
                
                // 排序选择器
                HStack(spacing: 20) {
                    ForEach(SortType.allCases, id: \.rawValue) { type in
                        Button(action: {
                            if sortType == type {
                                // 点击同一个类型时切换排序顺序
                                sortOrder = sortOrder == .descending ? .ascending : .descending
                            } else {
                                // 切换到新类型时，默认降序
                                sortType = type
                                sortOrder = .descending
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(type.rawValue)
                                    .font(.system(size: 14, weight: sortType == type ? .semibold : .regular))
                                
                                Image(systemName: getSortIcon(for: type))
                                    .font(.system(size: 12))
                                    .foregroundColor(sortType == type ? .blue : .secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(sortType == type ? Color.blue.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // 交易列表
                if sortedTransactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("暂无交易记录")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    List {
                        ForEach(sortedTransactions) { transaction in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    if !transaction.note.isEmpty {
                                        Text(transaction.note)
                                            .font(.system(size: 14, weight: .medium))
                                    } else {
                                        Text(transaction.category.name)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    
                                    Text(transaction.date, style: .date)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(transaction.amount.currencyFormatted)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(transaction.type == .income ? .green : .red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("交易明细")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("关闭") {
                isPresented = false
            })
        }
    }
}

struct CategoryDetailData: Identifiable {
    let id = UUID()
    let category: Category
    let transactions: [Transaction]
}

struct PieChartLegend: View {
    let data: [CategoryData]
    let total: Double
    let transactionStore: TransactionStore
    let transactionType: TransactionType
    @State private var selectedCategoryData: CategoryDetailData?
    
    private func getCategoryTransactions(_ category: Category) -> [Transaction] {
        return transactionStore.transactions.filter { 
            $0.category == category && $0.type == transactionType
        }
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(data) { categoryData in
                Button(action: {
                    // 创建数据对象，直接赋值给selectedCategoryData触发sheet
                    let transactions = getCategoryTransactions(categoryData.category)
                    selectedCategoryData = CategoryDetailData(
                        category: categoryData.category, 
                        transactions: transactions
                    )
                }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(categoryData.color)
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(categoryData.category.icon + " " + categoryData.category.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            
                            Text(categoryData.amount.currencyFormatted)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(categoryData.color)
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
        }
        .sheet(item: $selectedCategoryData) { data in
            // let _ = print("🔍 Opening category detail: \(data.category.name) with \(data.transactions.count) transactions")
            CategoryDetailPopover(
                category: data.category,
                transactions: data.transactions,
                isPresented: Binding(
                    get: { selectedCategoryData != nil },
                    set: { if !$0 { selectedCategoryData = nil } }
                )
            )
        }
    }
}

struct IncomePieChartView: View {
    @ObservedObject var store: TransactionStore
    
    private var incomeByCategory: [Category: Double] {
        var breakdown: [Category: Double] = [:]
        
        for transaction in store.transactions where transaction.type == .income {
            breakdown[transaction.category, default: 0] += transaction.amount
        }
        
        return breakdown
    }
    
    private var chartData: [CategoryData] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .cyan, .mint]
        
        return incomeByCategory.sorted(by: { $0.value > $1.value }).enumerated().map { index, element in
            CategoryData(
                category: element.key,
                amount: element.value,
                color: colors[index % colors.count].opacity(0.8)
            )
        }
    }
    
    private var totalIncome: Double {
        incomeByCategory.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("收入分类")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Text("总计: " + totalIncome.currencyFormatted)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            
            if chartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("暂无收入数据")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    // 饼图
                    PieChart(data: chartData, size: 140)
                    
                    // 图例
                    VStack(alignment: .leading, spacing: 0) {
                        PieChartLegend(data: chartData, total: totalIncome, transactionStore: store, transactionType: .income)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

struct ExpensePieChartView: View {
    @ObservedObject var store: TransactionStore
    
    private var expenseByCategory: [Category: Double] {
        var breakdown: [Category: Double] = [:]
        
        for transaction in store.transactions where transaction.type == .expense {
            breakdown[transaction.category, default: 0] += transaction.amount
        }
        
        return breakdown
    }
    
    private var chartData: [CategoryData] {
        let colors: [Color] = [.red, .orange, .yellow, .brown, .purple, .pink, .indigo, .gray]
        
        return expenseByCategory.sorted(by: { $0.value > $1.value }).enumerated().map { index, element in
            CategoryData(
                category: element.key,
                amount: element.value,
                color: colors[index % colors.count].opacity(0.8)
            )
        }
    }
    
    private var totalExpense: Double {
        expenseByCategory.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("支出分类")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Text("总计: " + totalExpense.currencyFormatted)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.horizontal)
            
            if chartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("暂无支出数据")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    // 饼图
                    PieChart(data: chartData, size: 140)
                    
                    // 图例
                    VStack(alignment: .leading, spacing: 0) {
                        PieChartLegend(data: chartData, total: totalExpense, transactionStore: store, transactionType: .expense)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 20) {
        IncomePieChartView(store: TransactionStore())
        ExpensePieChartView(store: TransactionStore())
    }
}

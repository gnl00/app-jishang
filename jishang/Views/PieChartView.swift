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

struct PieChartLegend: View {
    let data: [CategoryData]
    let total: Double
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(data) { categoryData in
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryData.color)
                        .frame(width: 12, height: 12)
                    
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
                color: colors[index % colors.count]
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
                        PieChartLegend(data: chartData, total: totalIncome)
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
                color: colors[index % colors.count]
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
                        PieChartLegend(data: chartData, total: totalExpense)
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
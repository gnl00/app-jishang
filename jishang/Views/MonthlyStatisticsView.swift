//
//  MonthlyStatisticsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - MonthlyStatisticsView: Main detailed monthly statistics page
//  - HealthDashboardView: Health score dashboard with 4 cards
//  - ConsumptionTrendView: Consumption trend analysis with chart
//  - CategoryInsightsView: Smart category insights TOP 5 analysis
//  - SmartTipView: Intelligent financial tips and suggestions
//  - MonthPickerView: Month selection picker component
//  - Category insight row and health score card components
//
//  Note: EmptyDataView and AbnormalSpendingAlert moved to MonthlyStatisticsComponents.swift
//

import SwiftUI
import Foundation

enum ChartViewMode: String, CaseIterable {
    case week = "周视图"
    case month = "月视图"
}

// MARK: - Monthly Statistics View
struct MonthlyStatisticsView: View {
    @ObservedObject var store: TransactionStore
    let monthDate: Date
    
    @State private var selectedMonth: Date
    @State private var selectedDate: Date?
    // TODO：chartViewMode 目前只在UI中显示切换按钮，实际图表逻辑尚未完全实现周/月视图切换
    @State private var chartViewMode: ChartViewMode = .month
    
    init(store: TransactionStore, monthDate: Date) {
        self.store = store
        self.monthDate = monthDate
        let calendar = Calendar.current
        self._selectedMonth = State(initialValue: calendar.startOfMonth(for: monthDate))
    }
    
    private var calendar: Calendar { Calendar.current }
    
    private var currentMonthIncome: Double {
        store.monthlyIncome(for: selectedMonth)
    }
    
    private var currentMonthExpense: Double {
        store.monthlyExpense(for: selectedMonth)
    }
    
    private var balance: Double {
        currentMonthIncome - currentMonthExpense
    }
    
    private var hasAnyExpense: Bool { 
        store.transactions.contains { 
            $0.type == .expense && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        } 
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("📊 月度消费数据")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.top)
                    
                    // 月份选择器
                    MonthPickerView(selectedMonth: $selectedMonth, store: store)
                    
                    // 消费健康度仪表盘
                    HealthDashboardView(
                        income: currentMonthIncome,
                        expense: currentMonthExpense,
                        balance: balance,
                        store: store,
                        selectedMonth: selectedMonth
                    )
                    
                    // 消费趋势分析
                    if hasAnyExpense {
                        ConsumptionTrendView(
                            store: store,
                            selectedMonth: selectedMonth,
                            selectedDate: $selectedDate,
                            viewMode: $chartViewMode
                        )
                    } else {
                        EmptyDataView()
                    }
                    
                    // 智能类别洞察
                    if hasAnyExpense {
                        CategoryInsightsView(store: store, selectedMonth: selectedMonth)
                    }
                    
                    // 智能理财建议
                    SmartTipView(
                        store: store,
                        selectedMonth: selectedMonth,
                        income: currentMonthIncome,
                        expense: currentMonthExpense
                    )
                    
                    Spacer(minLength: 20)
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .onChange(of: selectedMonth) { _, _ in
                selectedDate = nil
            }
        }
    }
}

// MARK: - 消费健康度仪表盘
struct HealthDashboardView: View {
    let income: Double
    let expense: Double
    let balance: Double
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    
    private var calendar: Calendar { Calendar.current }
    
    private var healthScore: Int {
        var score = 100
        
        // 支出占收入比例评分 (40分权重)
        if income > 0 {
            let expenseRatio = expense / income
            if expenseRatio > 0.9 {
                score -= 40
            } else if expenseRatio > 0.8 {
                score -= 30
            } else if expenseRatio > 0.7 {
                score -= 20
            } else if expenseRatio > 0.6 {
                score -= 10
            }
        }
        
        // 支出分类均衡度评分 (30分权重)
        let categoryBalance = calculateCategoryBalance()
        if categoryBalance < 0.3 {
            score -= 30
        } else if categoryBalance < 0.5 {
            score -= 20
        } else if categoryBalance < 0.7 {
            score -= 10
        }
        
        // 消费稳定性评分 (30分权重)
        let stability = calculateSpendingStability()
        if stability < 0.3 {
            score -= 30
        } else if stability < 0.5 {
            score -= 20
        } else if stability < 0.7 {
            score -= 10
        }
        
        return max(0, min(100, score))
    }
    
    private var monthlyChange: Double {
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        let lastMonthExpense = store.monthlyExpense(for: lastMonth)
        
        guard lastMonthExpense > 0 else { return 0 }
        return ((expense - lastMonthExpense) / lastMonthExpense) * 100
    }
    
    private var dailyAverage: Double {
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
        return expense / Double(daysInMonth)
    }
    
    private var spendingRhythm: Double {
        calculateSpendingStability()
    }
    
    private func calculateCategoryBalance() -> Double {
        let categoryTotals = store.monthlyCategoryTotals(for: selectedMonth, type: .expense)
        
        guard !categoryTotals.isEmpty else { return 1.0 }
        
        let values = Array(categoryTotals.values)
        let maxValue = values.max() ?? 0
        let totalValue = values.reduce(0, +)
        
        guard totalValue > 0 else { return 1.0 }
        
        // 计算最大类别占总支出的比例，比例越低说明越均衡
        let maxRatio = maxValue / totalValue
        return 1.0 - min(maxRatio, 1.0)
    }
    
    private func calculateSpendingStability() -> Double {
        let dailyTotals = store.dailyTotals(for: selectedMonth, type: .expense)
        
        let values = Array(dailyTotals.values)
        guard values.count > 1 else { return 1.0 }
        
        let average = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        guard average > 0 else { return 1.0 }
        
        let coefficientOfVariation = standardDeviation / average
        return max(0, 1.0 - min(coefficientOfVariation, 1.0))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎯 消费健康度仪表盘")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                // 健康度评分
                HealthScoreCard(score: healthScore)
                
                // 环比变化
                MonthlyChangeCard(change: monthlyChange)
                
                // 日均消费
                DailyAverageCard(average: dailyAverage)
                
                // 消费节奏
                SpendingRhythmCard(rhythm: spendingRhythm)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
    }
}

struct HealthScoreCard: View {
    let score: Int
    
    private var scoreColor: Color {
        if score >= 80 {
            return Color.green
        } else if score >= 60 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("健康度")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("\(score)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(scoreColor)
            
            Text("/100")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(scoreColor.opacity(0.1))
        )
    }
}

struct MonthlyChangeCard: View {
    let change: Double
    
    private var changeColor: Color {
        if change > 0 {
            return Color.red
        } else if change < 0 {
            return Color.green
        } else {
            return Color.secondary
        }
    }
    
    private var changeIcon: String {
        if change > 0 {
            return "arrow.up"
        } else if change < 0 {
            return "arrow.down"
        } else {
            return "minus"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("环比变化")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: changeIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(changeColor)
                Text("\(String(format: "%.1f", abs(change)))%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(changeColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

struct DailyAverageCard: View {
    let average: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("日均消费")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(average.currencyFormattedOneDecimal)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

struct SpendingRhythmCard: View {
    let rhythm: Double
    
    private var rhythmText: String {
        if rhythm >= 0.8 {
            return "均匀分布"
        } else if rhythm >= 0.6 {
            return "较为均匀"
        } else if rhythm >= 0.4 {
            return "稍有波动"
        } else {
            return "波动较大"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("消费节奏")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            // 进度条显示
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(Double(index) < rhythm * 10 ? Color.blue.opacity(0.8) : Color(.systemGray5))
                        .frame(width: 4, height: 8)
                        .cornerRadius(2)
                }
            }
            
            Text(rhythmText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - 消费趋势分析
struct ConsumptionTrendView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    @Binding var selectedDate: Date?
    @Binding var viewMode: ChartViewMode
    
    private var calendar: Calendar { Calendar.current }
    
    private var currentMonthIncome: Double {
        store.monthlyIncome(for: selectedMonth)
    }
    
    private var currentMonthExpense: Double {
        store.monthlyExpense(for: selectedMonth)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mode toggle
            HStack {
                Text("📈 消费趋势分析")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 视图模式切换
                HStack(spacing: 0) {
                    ForEach(ChartViewMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = mode
                            }
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(viewMode == mode ? .white : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewMode == mode ? Color.primary : Color.clear)
                                )
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            
            // 数据概览
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.green.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 8, height: 8)
                    Text("收入: \(currentMonthIncome.currencyFormattedInt)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.6), Color.red.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 8, height: 8)
                    Text("支出: \(currentMonthExpense.currencyFormattedInt)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // 图表区域 - 缩小高度
            ScrollableBarChartView(store: store, selectedMonth: selectedMonth, selectedDate: $selectedDate)
                .frame(height: 200)
            
            // 点击提示
            Text("💡 点击柱状图查看详情")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
    }
}


// MARK: - 智能类别洞察
struct CategoryInsightsView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    
    private var calendar: Calendar { Calendar.current }
    
    private var categoryInsights: [(category: Category, amount: Double, percentage: Double, change: Double)] {
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        
        let categoryTotals = store.monthlyCategoryTotals(for: selectedMonth, type: .expense)
        let lastMonthTotals = store.monthlyCategoryTotals(for: lastMonth, type: .expense)
        
        let totalExpense = categoryTotals.values.reduce(0, +)
        
        return categoryTotals.compactMap { (category, amount) in
            let percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0
            let lastAmount = lastMonthTotals[category, default: 0]
            let change = lastAmount > 0 ? ((amount - lastAmount) / lastAmount) * 100 : 0
            return (category: category, amount: amount, percentage: percentage, change: change)
        }.sorted { $0.amount > $1.amount }
    }
    
    private var topCategory: (category: Category, amount: Double, percentage: Double, change: Double)? {
        categoryInsights.first
    }
    
    private var hasAbnormalSpending: Bool {
        categoryInsights.contains { $0.change > 50 || $0.percentage > 60 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🏷️ 支出类别洞察 TOP 5")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if categoryInsights.isEmpty {
                Text("暂无支出数据")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(categoryInsights.prefix(5).enumerated()), id: \.offset) { index, item in
                        CategoryInsightRow(
                            category: item.category,
                            amount: item.amount,
                            percentage: item.percentage,
                            change: item.change,
                            isTop: index == 0
                        )
                    }
                }
                
                // 异常提醒
                if hasAbnormalSpending, let top = topCategory {
                    AbnormalSpendingAlert(category: top.category, change: top.change, percentage: top.percentage)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
    }
}

struct CategoryInsightRow: View {
    let category: Category
    let amount: Double
    let percentage: Double
    let change: Double
    let isTop: Bool
    
    private var changeColor: Color {
        if change > 20 {
            return Color.red
        } else if change > 0 {
            return Color.orange
        } else if change < -10 {
            return Color.green
        } else {
            return Color.secondary
        }
    }
    
    private var progressColor: LinearGradient {
        if isTop && percentage > 50 {
            return LinearGradient(
                colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.red.opacity(0.6), Color.red.opacity(0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(category.icon) \(category.name)")
                    .font(.system(size: 14, weight: isTop ? .semibold : .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(percentage.percentFormattedOneDecimal)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        if abs(change) > 5 {
                            Text(change > 0 ? "+\(String(format: "%.0f", change))%" : "\(String(format: "%.0f", change))%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(changeColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(changeColor.opacity(0.1))
                                )
                        }
                    }
                    
                    Text(amount.currencyFormattedInt)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                        .animation(.easeInOut(duration: 0.8), value: percentage)
                }
            }
            .frame(height: 6)
        }
    }
}


// MARK: - 智能理财建议
struct SmartTipView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    let income: Double
    let expense: Double
    
    private var calendar: Calendar { Calendar.current }
    
    private var monthlyHighlights: [String] {
        var highlights: [String] = []
        
        // 节余情况
        let balance = income - expense
        if balance > income * 0.3 {
            highlights.append("交通费用控制良好，比预算节省¥\(String(format: "%.0f", balance * 0.1))")
        }
        
        // 记账情况
        let monthTransactions = store.monthlyTransactions(for: selectedMonth)
        
        let recordingDays = Set(monthTransactions.map { calendar.startOfDay(for: $0.date) }).count
        if recordingDays > 20 {
            highlights.append("记账习惯保持良好，已记录\(recordingDays)天")
        }
        
        if highlights.isEmpty {
            highlights.append("娱乐支出合理，保持了生活品质")
        }
        
        return highlights
    }
    
    private var improvementSuggestions: [String] {
        var suggestions: [String] = []
        
        // 分析类别支出
        let categoryTotals = store.monthlyCategoryTotals(for: selectedMonth, type: .expense)
        let categoryNameTotals = Dictionary(uniqueKeysWithValues: categoryTotals.map { ($0.key.name, $0.value) })
        
        if let topCategory = categoryNameTotals.max(by: { $0.value < $1.value }) {
            let percentage = (topCategory.value / expense) * 100
            if percentage > 40 {
                let suggestedBudget = topCategory.value * 0.8
                suggestions.append("可设定\(topCategory.key)月预算¥\(String(format: "%.0f", suggestedBudget))，当前超出¥\(String(format: "%.0f", topCategory.value - suggestedBudget))")
            }
        }
        
        // 记账建议
        let monthTransactions = store.monthlyTransactions(for: selectedMonth)
        let recordingDays = Set(monthTransactions.map { calendar.startOfDay(for: $0.date) }).count
        if recordingDays < 15 {
            suggestions.append("建议开启自动记账提醒，避免遗漏小额支出")
        }
        
        return suggestions
    }
    
    private var monthlyAchievements: [String] {
        var achievements: [String] = []
        
        // 计算记账天数
        let monthTransactions = store.monthlyTransactions(for: selectedMonth)
        let recordingDays = Set(monthTransactions.map { calendar.startOfDay(for: $0.date) }).count
        
        if recordingDays >= 28 {
            achievements.append("🏆 连续记账\(recordingDays)天")
        }
        
        let balance = income - expense
        if balance > 0 {
            achievements.append("💰 成功结余\(balance.currencyFormattedInt)")
        }
        
        if achievements.isEmpty {
            achievements.append("🎆 开始理财之旅")
        }
        
        return achievements
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💡 智能理财建议")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 16) {
                // 本月亮点
                if !monthlyHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✨ 本月亮点")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(monthlyHighlights, id: \.self) { highlight in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text(highlight)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // 改进建议
                if !improvementSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎯 改进建议")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(improvementSuggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text(suggestion)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // 月度成就
                if !monthlyAchievements.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🏆 月度成就")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            ForEach(monthlyAchievements, id: \.self) { achievement in
                                Text(achievement)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.08),
                            Color.green.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.2),
                                    Color.green.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 月份选择器
struct MonthPickerView: View {
    @Binding var selectedMonth: Date
    @ObservedObject var store: TransactionStore
    
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        
        // 获取所有交易数据的月份
        let transactionMonths = Set(store.transactions.map { transaction in
            calendar.startOfMonth(for: transaction.date)
        })
        
        // 如果没有交易数据，返回当前月份
        if transactionMonths.isEmpty {
            return [calendar.startOfMonth(for: Date())]
        }
        
        // 按时间降序排列（最新的在前）
        return Array(transactionMonths).sorted(by: >)
    }
    
    private var normalizedSelectedMonth: Date {
        let calendar = Calendar.current
        let normalized = calendar.startOfMonth(for: selectedMonth)
        
        // 确保选中的月份在可用月份列表中，如果不在则使用第一个可用月份
        if availableMonths.contains(normalized) {
            return normalized
        } else {
            return availableMonths.first ?? normalized
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if availableMonths.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Menu {
                    ForEach(availableMonths, id: \.self) { month in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMonth = month
                            }
                        }) {
                            HStack {
                                Text(monthFormatter.string(from: month))
                                if normalizedSelectedMonth == month {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(monthFormatter.string(from: normalizedSelectedMonth))
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .onAppear {
            // 当视图出现时，如果当前选中的月份不在可用列表中，自动切换到第一个可用月份
            let normalized = Calendar.current.startOfMonth(for: selectedMonth)
            if !availableMonths.contains(normalized), let firstMonth = availableMonths.first {
                selectedMonth = firstMonth
            }
        }
    }
    
    private var monthFormatter: DateFormatter {
        DateFormatter.yearMonth
    }
}


#Preview {
    MonthlyStatisticsView(store: TransactionStore(), monthDate: Date())
}

//
//  StatisticsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI
import Pow

struct StatisticsView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @State private var timeRangeFilter: TimeRangeFilter = .allTime

    enum TimeRangeFilter: String, CaseIterable {
        case allTime = "全部时间"
        case lastYear = "近一年"
        case lastSixMonths = "近6个月"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with time filter - 采用HomeView的简洁风格
                    HStack {
                        Text("💼 财务总览")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        // Time range filter - 简化设计
                        Menu {
                            ForEach(TimeRangeFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        timeRangeFilter = filter
                                    }
                                }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if timeRangeFilter == filter {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(timeRangeFilter.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Cumulative data cards
                    CumulativeDataCardsView(store: transactionStore, timeFilter: timeRangeFilter)

                    // Net worth trend chart
                    NetWorthTrendView(store: transactionStore)
                    
                    // Monthly comparison analysis
                    MonthlyComparisonView(store: transactionStore)

                    // Monthly performance ranking
                    MonthlyRankingView(store: transactionStore)

                    // Financial health score
                    FinancialHealthScoreView(store: transactionStore)

                    // Financial achievements
                    FinancialAchievementsView(store: transactionStore)

                    Spacer(minLength: 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Cumulative Data Cards
struct CumulativeDataCardsView: View {
    @ObservedObject var store: TransactionStore
    let timeFilter: StatisticsView.TimeRangeFilter

    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return store.transactions.filter { transaction in
            switch timeFilter {
            case .allTime:
                return true
            case .lastYear:
                return calendar.dateInterval(of: .year, for: now)?.contains(transaction.date) ?? false ||
                       calendar.dateInterval(of: .year, for: calendar.date(byAdding: .year, value: -1, to: now) ?? now)?.contains(transaction.date) ?? false
            case .lastSixMonths:
                return transaction.date >= calendar.date(byAdding: .month, value: -6, to: now) ?? now
            }
        }
    }

    private var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var netWorth: Double {
        totalIncome - totalExpense
    }

    private var totalMonths: Int {
        guard !filteredTransactions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let dates = filteredTransactions.map { $0.date }
        let startDate = dates.min() ?? Date()
        let endDate = dates.max() ?? Date()
        return calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
    }

    private var totalTransactions: Int {
        filteredTransactions.count
    }

    private var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netWorth / totalIncome) * 100
    }

    private var avgMonthlyIncome: Double {
        guard totalMonths > 0 else { return 0 }
        return totalIncome / Double(totalMonths)
    }

    private var avgDailyExpense: Double {
        guard !filteredTransactions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let expenseTransactions = filteredTransactions.filter { $0.type == .expense }
        guard !expenseTransactions.isEmpty else { return 0 }

        let startDate = expenseTransactions.map { $0.date }.min() ?? Date()
        let endDate = expenseTransactions.map { $0.date }.max() ?? Date()
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        return totalExpense / Double(max(days, 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 核心数据 - 仿照MonthlySummaryView的三列设计
            HStack(spacing: 0) {
                // 总收入
                VStack(spacing: 6) {
                    Text("总收入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(totalIncome.currencyFormattedInt)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text("\(totalMonths)个月")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分隔线
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 1, height: 55)

                // 总支出
                VStack(spacing: 6) {
                    Text("总支出")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(totalExpense.currencyFormattedInt)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text("\(totalTransactions)笔")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 分隔线
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 1, height: 55)

                // 净资产
                VStack(spacing: 6) {
                    Text("净资产")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(netWorth.currencyFormattedInt)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(netWorth >= 0 ? .primary : Color.red)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text("储蓄率\(savingsRate.percentFormattedInt)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct EnhancedStatisticCard: View {
    let icon: String
    let title: String
    let mainValue: String
    let subtitle: String
    let additionalInfo: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Text(icon)
                .font(.system(size: 24))

            // Title
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            // Main Value
            Text(mainValue)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Spacer()

            // Subtitle
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            // Additional Info
            Text(additionalInfo)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Monthly Comparison View
struct MonthlyComparisonView: View {
    @ObservedObject var store: TransactionStore

    private var last12Months: [Date] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<12).compactMap { i in
            calendar.date(byAdding: .month, value: -i, to: now)
        }.reversed()
    }

    private func monthlyData(for month: Date) -> (income: Double, expense: Double, growth: Double) {
        let income = store.monthlyIncome(for: month)
        let expense = store.monthlyExpense(for: month)

        // Calculate growth compared to previous month
        let calendar = Calendar.current
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: month) ?? month
        let previousExpense = store.monthlyExpense(for: previousMonth)
        let growth = previousExpense > 0 ? ((expense - previousExpense) / previousExpense) * 100 : 0

        return (income, expense, growth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - 统一样式
            HStack {
                Text("📈 月度趋势")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 16) {
                // 只显示最近3个月，减少信息密度
                VStack(alignment: .leading, spacing: 12) {
                    Text("支出趋势 (近3个月)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    ForEach(last12Months.suffix(3), id: \.self) { month in
                        let data = monthlyData(for: month)
                        SimplifiedTrendRow(
                            month: month,
                            amount: data.expense,
                            growth: data.growth
                        )
                    }
                }

                // 简化洞察信息
                if let latestMonth = last12Months.last {
                    let data = monthlyData(for: latestMonth)
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue.opacity(0.7))
                            .font(.system(size: 12))
                        Text(data.growth > 5 ? "支出较上月增长\(data.growth.percentFormattedInt)" :
                             data.growth < -5 ? "支出较上月减少\(abs(data.growth).percentFormattedInt)" : "支出基本稳定")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// 简化的趋势行组件
struct SimplifiedTrendRow: View {
    let month: Date
    let amount: Double
    let growth: Double

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter
    }

    var body: some View {
        HStack {
            Text(monthFormatter.string(from: month))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            Text(amount.currencyFormattedInt)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            if abs(growth) > 5 {
                HStack(spacing: 4) {
                    Image(systemName: growth > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(growth > 0 ? .red.opacity(0.7) : .green.opacity(0.7))
                    Text("\(abs(growth).percentFormattedInt)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("持平")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MonthlyTrendRow: View {
    let month: Date
    let amount: Double
    let type: TransactionType
    let growth: Double

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter
    }

    private var progressWidth: CGFloat {
        // Normalize amount to progress bar width (0-1)
        let maxAmount: Double = 10000 // You might want to calculate this dynamically
        return min(CGFloat(amount / maxAmount), 1.0)
    }

    var body: some View {
        HStack {
            Text(monthFormatter.string(from: month))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(type == .income ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                        .frame(width: geometry.size.width * progressWidth, height: 8)
                }
            }
            .frame(height: 8)

            Text(amount.currencyFormattedShort)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .trailing)

            if abs(growth) > 5 {
                HStack(spacing: 2) {
                    Image(systemName: growth > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8))
                        .foregroundColor(growth > 0 ? .red : .green)
                    Text("\(abs(growth).percentFormattedInt)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(growth > 0 ? .red : .green)
                }
                .frame(width: 50, alignment: .trailing)
            } else {
                Spacer()
                    .frame(width: 50)
            }
        }
    }
}

// MARK: - Net Worth Trend View - 简化版
struct NetWorthTrendView: View {
    @ObservedObject var store: TransactionStore
    @State private var isFlipped = false
    @State private var newGoalText = ""
    @State private var showQuickOptions = false

    private var currentNetWorth: Double {
        store.balance
    }

    private var targetAmount: Double {
        store.savingsGoal
    }

    private var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        return min((currentNetWorth / targetAmount) * 100, 100)
    }

    private var remainingAmount: Double {
        max(0, targetAmount - currentNetWorth)
    }

    private var monthlyGrowth: Double {
        let calendar = Calendar.current
        let thisMonth = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth

        let thisMonthBalance = store.monthlyIncome(for: thisMonth) - store.monthlyExpense(for: thisMonth)
        let lastMonthBalance = store.monthlyIncome(for: lastMonth) - store.monthlyExpense(for: lastMonth)

        guard lastMonthBalance != 0 else { return 0 }
        return ((thisMonthBalance - lastMonthBalance) / abs(lastMonthBalance)) * 100
    }

    var body: some View {
        Group {
            if !isFlipped {
                goalProgressCard
            } else {
                goalEditCard
            }
        }
        .transition(.move(edge: .leading))
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
                if isFlipped {
                    newGoalText = String(format: "%.0f", targetAmount)
                }
            }
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 正面卡片 (目标进度)
    private var goalProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - 简洁设计
            HStack {
                Text("🎯 目标进度")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()

                // 轻微提示
                Text("双击编辑")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            VStack(spacing: 12) {
                // 目标进度条 - 简化设计
                VStack(spacing: 8) {
                    HStack {
                        Text("储蓄目标 \(targetAmount.currencyFormattedInt)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(progressPercentage.percentFormattedInt)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(
                                    colors: [.blue.opacity(0.7), .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(
                                    width: geometry.size.width * CGFloat(progressPercentage / 100),
                                    height: 12
                                )
                        }
                    }
                    .frame(height: 12)
                }

                // 关键信息 - 简化显示
                HStack {
                    Text("本月净收入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if abs(monthlyGrowth) > 5 {
                        HStack(spacing: 4) {
                            Image(systemName: monthlyGrowth > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(monthlyGrowth > 0 ? .green : .red)
                            Text("\(abs(monthlyGrowth).percentFormattedInt)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("持平")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
    }

    // MARK: - 背面卡片 (编辑界面)
    private var goalEditCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("💰 设置目标")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()

                Button("完成") {
                    saveGoal()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
            }

            VStack(spacing: 16) {
                // 当前目标显示
                Text("当前: \(targetAmount.currencyFormattedInt)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                // 金额输入框
                HStack {
                    Text("¥")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)

                    TextField("输入目标金额", text: $newGoalText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6).opacity(0.5))
                        )
                        .padding(.vertical, 8)
                }

                // 快速选择
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([10000, 30000, 50000, 100000, 200000], id: \.self) { amount in
                            Button(action: {
                                newGoalText = String(format: "%.0f", amount)
                                // 轻微触觉反馈
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                Text(amount.currencyFormattedShort)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(newGoalText == String(format: "%.0f", amount) ? .white : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(newGoalText == String(format: "%.0f", amount) ? .blue : .blue.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .onAppear {
            newGoalText = String(format: "%.0f", targetAmount)
        }
    }

    // MARK: - 保存目标
    private func saveGoal() {
        if let amount = Double(newGoalText), amount > 0 {
            store.updateSavingsGoal(amount)
            // 成功触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }

        // 翻转回正面 - 使用优化的动画参数
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isFlipped = false
        }
    }
}



// MARK: - Monthly Ranking View
struct MonthlyRankingView: View {
    @ObservedObject var store: TransactionStore

    private var last12Months: [Date] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<12).compactMap { i in
            calendar.date(byAdding: .month, value: -i, to: now)
        }.reversed()
    }

    private var monthlyPerformance: [(month: Date, income: Double, expense: Double, savings: Double, savingsRate: Double)] {
        return last12Months.map { month in
            let income = store.monthlyIncome(for: month)
            let expense = store.monthlyExpense(for: month)
            let savings = income - expense
            let savingsRate = income > 0 ? (savings / income) * 100 : 0
            return (month, income, expense, savings, savingsRate)
        }
    }

    private var bestSavingsMonth: (month: Date, amount: Double, rate: Double)? {
        let performance = monthlyPerformance.max { $0.savings < $1.savings }
        guard let best = performance else { return nil }
        return (best.month, best.savings, best.savingsRate)
    }

    private var highestIncomeMonth: (month: Date, amount: Double)? {
        let performance = monthlyPerformance.max { $0.income < $1.income }
        guard let best = performance else { return nil }
        return (best.month, best.income)
    }

    private var lowestExpenseMonth: (month: Date, amount: Double)? {
        let performance = monthlyPerformance.filter { $0.expense > 0 }.min { $0.expense < $1.expense }
        guard let best = performance else { return nil }
        return (best.month, best.expense)
    }

    private var highestExpenseMonth: (month: Date, amount: Double)? {
        let performance = monthlyPerformance.max { $0.expense < $1.expense }
        guard let highest = performance else { return nil }
        return (highest.month, highest.expense)
    }

    private var averageIncome: Double {
        let total = monthlyPerformance.reduce(0) { $0 + $1.income }
        return monthlyPerformance.count > 0 ? total / Double(monthlyPerformance.count) : 0
    }

    private var averageExpense: Double {
        let total = monthlyPerformance.reduce(0) { $0 + $1.expense }
        return monthlyPerformance.count > 0 ? total / Double(monthlyPerformance.count) : 0
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - 统一样式
            HStack {
                Text("🧩 月度表现")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 12) {
                // 只显示最重要的2个指标
                if let bestSavings = bestSavingsMonth {
                    SimplifiedRankingRow(
                        icon: "🏆",
                        title: "最佳储蓄月",
                        subtitle: "\(monthFormatter.string(from: bestSavings.month)) \(bestSavings.amount.currencyFormattedInt)"
                    )
                }

                if let highestExpense = highestExpenseMonth {
                    SimplifiedRankingRow(
                        icon: "📊",
                        title: "支出最高月",
                        subtitle: "\(monthFormatter.string(from: highestExpense.month)) \(highestExpense.amount.currencyFormattedInt)"
                    )
                }

                // 月度平均 - 简化信息
                HStack {
                    Text("月度平均")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("支出\(averageExpense.currencyFormattedInt)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// 简化的排名行组件 - 匹配HomeView风格
struct SimplifiedRankingRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct RankingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPositive: Bool

    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(isPositive ? .green : .orange)
            }

            Spacer()
        }
    }
}

// MARK: - Financial Health Score View - 简化版
struct FinancialHealthScoreView: View {
    @ObservedObject var store: TransactionStore

    private var savingsRate: Double {
        let income = store.totalIncome
        let expense = store.totalExpense
        guard income > 0 else { return 0 }
        return ((income - expense) / income) * 100
    }

    private var recordingHabit: Double {
        let calendar = Calendar.current
        let now = Date()
        let last30Days = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        let recentTransactions = store.transactions.filter { $0.date >= last30Days }
        let recordingDays = Set(recentTransactions.map { calendar.startOfDay(for: $0.date) }).count

        return Double(recordingDays) / 30.0 * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - 统一样式
            HStack {
                Text("💪 财务健康")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 12) {
                // 只显示2个最核心的指标，简化呈现
                SimplifiedHealthRow(
                    title: "储蓄能力",
                    value: savingsRate,
                    unit: "%",
                    status: savingsRate >= 30 ? "优秀" : savingsRate >= 20 ? "良好" : "需改进"
                )

                SimplifiedHealthRow(
                    title: "记账频率",
                    value: recordingHabit,
                    unit: "%",
                    status: recordingHabit >= 80 ? "优秀" : recordingHabit >= 60 ? "良好" : "需改进"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// 简化的健康指标行
struct SimplifiedHealthRow: View {
    let title: String
    let value: Double
    let unit: String
    let status: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(value.percentFormattedInt)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Financial Achievements View
struct FinancialAchievementsView: View {
    @ObservedObject var store: TransactionStore

    private var achievements: [Achievement] {
        var results: [Achievement] = []

        // Recording streak
        let recordingDays = calculateRecordingStreak()
        if recordingDays >= 30 {
            results.append(Achievement(
                icon: "💎",
                title: "连续记账",
                subtitle: "\(recordingDays)天",
                type: .streak
            ))
        }

        // Savings achievement
        let currentBalance = store.balance
        if currentBalance >= 30000 {
            results.append(Achievement(
                icon: "💰",
                title: "储蓄达成",
                subtitle: "\(currentBalance.currencyFormattedShort)+",
                type: .savings
            ))
        }

        // Income growth
        let growthRate = calculateIncomeGrowth()
        if growthRate > 20 {
            results.append(Achievement(
                icon: "📈",
                title: "收入增长",
                subtitle: "+\(growthRate.percentFormattedInt)",
                type: .growth
            ))
        }

        // Goal progress
        let goalProgress = (currentBalance / 40000) * 100
        if goalProgress >= 75 {
            results.append(Achievement(
                icon: "🎯",
                title: "目标进度",
                subtitle: "\(goalProgress.percentFormattedInt)达成",
                type: .goal
            ))
        }

        // Expense control
        let controlMonths = calculateExpenseControlMonths()
        if controlMonths >= 3 {
            results.append(Achievement(
                icon: "📊",
                title: "支出控制",
                subtitle: "\(controlMonths)个月优秀",
                type: .control
            ))
        }

        // Rising star
        if results.count >= 3 {
            results.append(Achievement(
                icon: "✨",
                title: "理财新星",
                subtitle: "进步显著",
                type: .star
            ))
        }

        return results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - 统一样式
            HStack {
                Text("🏆 财务成就")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            if achievements.isEmpty {
                Text("继续努力，即将解锁新成就！")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // 简化为2列布局，减少视觉密度
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(achievements.prefix(4), id: \.title) { achievement in
                        SimplifiedAchievementCard(achievement: achievement)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func calculateRecordingStreak() -> Int {
        let calendar = Calendar.current
        let now = Date()
        var streak = 0
        var currentDate = calendar.startOfDay(for: now)

        while true {
            let hasTransaction = store.transactions.contains { transaction in
                calendar.isDate(transaction.date, inSameDayAs: currentDate)
            }

            if hasTransaction {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        return streak
    }

    private func calculateIncomeGrowth() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let thisYear = calendar.component(.year, from: now)
        let lastYear = thisYear - 1

        let thisYearIncome = store.transactions
            .filter { $0.type == .income && calendar.component(.year, from: $0.date) == thisYear }
            .reduce(0) { $0 + $1.amount }

        let lastYearIncome = store.transactions
            .filter { $0.type == .income && calendar.component(.year, from: $0.date) == lastYear }
            .reduce(0) { $0 + $1.amount }

        guard lastYearIncome > 0 else { return 0 }
        return ((thisYearIncome - lastYearIncome) / lastYearIncome) * 100
    }

    private func calculateExpenseControlMonths() -> Int {
        let calendar = Calendar.current
        let now = Date()
        var controlMonths = 0

        for i in 0..<6 {
            let month = calendar.date(byAdding: .month, value: -i, to: now) ?? now
            let expense = store.monthlyExpense(for: month)
            let income = store.monthlyIncome(for: month)

            // Good control if expense is less than 80% of income
            if income > 0 && (expense / income) < 0.8 {
                controlMonths += 1
            }
        }

        return controlMonths
    }
}

struct Achievement {
    let icon: String
    let title: String
    let subtitle: String
    let type: AchievementType

    enum AchievementType {
        case streak, savings, growth, goal, control, star
    }
}

// 简化的成就卡片 - 使用极简色彩系统
struct SimplifiedAchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.icon)
                .font(.system(size: 20))

            Text(achievement.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Text(achievement.subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 65)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    private var backgroundColor: Color {
        switch achievement.type {
        case .streak: return .purple.opacity(0.1)
        case .savings: return .green.opacity(0.1)
        case .growth: return .blue.opacity(0.1)
        case .goal: return .orange.opacity(0.1)
        case .control: return .indigo.opacity(0.1)
        case .star: return .yellow.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch achievement.type {
        case .streak: return .purple.opacity(0.3)
        case .savings: return .green.opacity(0.3)
        case .growth: return .blue.opacity(0.3)
        case .goal: return .orange.opacity(0.3)
        case .control: return .indigo.opacity(0.3)
        case .star: return .yellow.opacity(0.3)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.icon)
                .font(.system(size: 24))

            Text(achievement.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(achievement.subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }
}

#Preview {
    StatisticsView()
        .environmentObject(TransactionStore())
}

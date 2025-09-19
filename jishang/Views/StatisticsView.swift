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
    @State private var timeRange: TimeRange = .allTime

    enum TimeRange: String, CaseIterable {
        case allTime = "全部时间"
        case last12Months = "近12个月"
        case last6Months = "近6个月"
        case last3Months = "近3个月"
    }

    // DataScope removed from header; trend section manages its own type filters

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Cumulative data cards
                    CumulativeDataCardsView(store: transactionStore, timeFilter: timeRange)

                    // Net worth trend chart
                    NetWorthTrendView(store: transactionStore)
                    
                    // Trend section
                    StatsTrendSection(store: transactionStore, timeRange: timeRange)

                    // Monthly performance ranking
                    MonthlyRankingView(store: transactionStore, timeRange: timeRange)

                    // Financial health score
                    FinancialHealthScoreView(store: transactionStore, timeRange: timeRange)

                    // Financial achievements
                    FinancialAchievementsView(store: transactionStore)

                    Spacer(minLength: 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear { loadPreferences() }
            .onChange(of: timeRange) { _, _ in savePreferences() }
            
        }
    }
}

// MARK: - Header Bar
private extension StatisticsView {
    var headerBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("💼 财务总览")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                // 时间范围
                Menu {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { timeRange = range }
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                if timeRange == range { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 12, weight: .semibold))
                        Text(timeRange.rawValue)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Persist user preferences for filters
private extension StatisticsView {
    var timeRangeKey: String { "stats_timeRange" }

    func savePreferences() {
        UserDefaults.standard.set(timeRange.rawValue, forKey: timeRangeKey)
        // 仅持久化时间范围；趋势区的筛选在该区内处理
    }

    func loadPreferences() {
        if let tr = UserDefaults.standard.string(forKey: timeRangeKey), let v = TimeRange(rawValue: tr) {
            timeRange = v
        }
        // 无需加载趋势区本地筛选（保留上次默认即可）
    }
}

// (Moved CumulativeDataCardsView to Views/Statistics/CumulativeDataCardsView.swift)

// (Moved StatsTrendSection to Views/Statistics/StatsTrendSection.swift)

// MARK: - Net Worth Trend View - 简化版
struct NetWorthTrendView: View {
    @ObservedObject var store: TransactionStore
    @State private var isFlipped = false
    @State private var newGoalText = ""
    @State private var showQuickOptions = false
    @State private var monthlyAdjustment: Double = 0 // 每月多存/少花模拟
    private let avgWindowMonths: Int = 6
    
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
    
    private var avgMonthlyNet: Double {
        let calendar = Calendar.current
        let startOfCurrentMonth = calendar.startOfMonth(for: Date())
        let months = (0..<avgWindowMonths).compactMap { i in
            calendar.date(byAdding: .month, value: -i, to: startOfCurrentMonth)
        }
        guard !months.isEmpty else { return 0 }
        let values = months.map { store.monthlyIncome(for: $0) - store.monthlyExpense(for: $0) }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }
    
    private var adjustedNetPerMonth: Double {
        max(0, avgMonthlyNet + monthlyAdjustment)
    }
    
    private var estimatedMonthsToTarget: Int? {
        guard adjustedNetPerMonth > 0, remainingAmount > 0 else { return nil }
        return Int(ceil(remainingAmount / adjustedNetPerMonth))
    }
    
    private var estimatedTargetMonthString: String? {
        guard let m = estimatedMonthsToTarget else { return nil }
        let calendar = Calendar.current
        let base = calendar.startOfMonth(for: Date())
        if let target = calendar.date(byAdding: .month, value: m, to: base) {
            let f = DateFormatter(); f.dateFormat = "yyyy年M月"
            return f.string(from: target)
        }
        return nil
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
        StatsSectionCard {
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("预计达成")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            if let monthStr = estimatedTargetMonthString, let m = estimatedMonthsToTarget {
                                Text("\(monthStr)（约\(m)个月）")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                            } else {
                                Text("当前无法可靠预测")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 模拟器：每月多存/少花
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("每月多存/少花：")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let sign = monthlyAdjustment >= 0 ? "+" : "-"
                                let absValue = abs(monthlyAdjustment)
                                Text("\(sign)\(absValue.currencyFormattedInt)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .overlay(
                                        Text("") // placeholder to keep layout stable
                                    )
                            }
                            Slider(value: $monthlyAdjustment, in: -3000...3000, step: 100)
                            Text("基于近\(avgWindowMonths)个月平均月结余 \(avgMonthlyNet.currencyFormattedInt)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 背面卡片 (编辑界面)
    private var goalEditCard: some View {
        StatsSectionCard {
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
            .onAppear {
                newGoalText = String(format: "%.0f", targetAmount)
            }
        }
    }

    // MARK: - 保存目标
    private func saveGoal() {
        if let amount = Double(newGoalText), amount > 0 {
            store.updateSavingsGoal(amount)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isFlipped = false
        }
    }
}


// (Moved MonthlyRankingView to Views/Statistics/MonthlyRankingSection.swift)

// (Moved MonthlyRankingView & row to Views/Statistics/MonthlyRankingSection.swift)

// (Moved FinancialHealthScoreView & SimplifiedHealthRow to Views/Statistics/FinancialHealthSection.swift)


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

// (Removed unused alternative AchievementCard)

#Preview {
    StatisticsView()
        .environmentObject(TransactionStore())
}

//
//  MonthlyStatisticsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//  
//  Contains:
//  - MonthlySummaryView: Monthly summary card for home page
//  - MonthlyStatisticsView: Detailed monthly statistics view
//

import SwiftUI
import Pow

struct MonthlySummaryView: View {
    @ObservedObject var store: TransactionStore
    @State private var selectedPeriod = 0
    @State private var isExpanded = false
    @State private var showDailyExpenseDetails = false
    
    private var selectedDate: Date {
        let calendar = Calendar.current
        if selectedPeriod == 0 {
            return Date()
        } else {
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }
    
    private var currentMonthIncome: Double {
        store.monthlyIncome(for: selectedDate)
    }
    
    private var currentMonthExpense: Double {
        store.monthlyExpense(for: selectedDate)
    }
    
    private var balance: Double {
        currentMonthIncome - currentMonthExpense
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Section 1: Header with title and buttons
            HeaderSectionView(isExpanded: $isExpanded) {
                showDailyExpenseDetails = true
            }
            
            // Section 2: Monthly income details
            IncomeDetailsView(income: currentMonthIncome)
            
            // Section 3: Monthly cost and balance with progress bars
            CostBalanceProgressView(
                expense: currentMonthExpense,
                balance: balance,
                totalIncome: currentMonthIncome
            )
            
            // Section 4: SegmentedControl for month switching
            MonthSwitcherView(selectedPeriod: $selectedPeriod)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        )
        .padding(.horizontal)
        .sheet(isPresented: $showDailyExpenseDetails) {
            MonthlyStatisticsView(store: store, monthDate: selectedDate)
        }
    }
}

// MARK: - Header Section with Title and Expand Arrow
struct HeaderSectionView: View {
    @Binding var isExpanded: Bool
    var onShowDetails: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Text("月度总览")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                onShowDetails?()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Monthly Statistics View
struct MonthlyStatisticsView: View {
    @ObservedObject var store: TransactionStore
    let monthDate: Date
    
    @State private var selectedMonth: Date
    @State private var selectedDate: Date? // 将选中状态提升到这里
    
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
    
    private var balancePercentage: Double {
        guard currentMonthIncome > 0 else { return 0 }
        return balance / currentMonthIncome * 100
    }
    
    private var hasAnyExpense: Bool { 
        store.transactions.contains { 
            $0.type == .expense && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        } 
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: selectedMonth)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("月度消费数据")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.top)
                    
                    // 月份选择器
                    MonthPickerView(selectedMonth: $selectedMonth, store: store)
                    
                    // 收入支出概览
                    MonthlyOverviewView(
                        income: currentMonthIncome,
                        expense: currentMonthExpense,
                        balance: balance,
                        balancePercentage: balancePercentage
                    )
                    
                    // 消费趋势柱状图
                    if hasAnyExpense {
                        ConsumptionTrendView(store: store, selectedMonth: selectedMonth, selectedDate: $selectedDate)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("暂无支出数据")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    
                    // 支出类别分布
                    if hasAnyExpense {
                        ExpenseCategoryDistributionView(store: store, selectedMonth: selectedMonth)
                    }
                    
                    // 智能提示
                    SmartTipView(store: store, selectedMonth: selectedMonth)
                    
                    Spacer(minLength: 20)
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .onChange(of: selectedMonth) { _, _ in
                // 月份切换时重置选中状态
                selectedDate = nil
            }
        }
    }
}

struct ScrollableBarChartView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date?
    @Binding var selectedDate: Date?
    
    init(store: TransactionStore, selectedMonth: Date? = nil, selectedDate: Binding<Date?> = .constant(nil)) {
        self.store = store
        self.selectedMonth = selectedMonth
        self._selectedDate = selectedDate
    }
    
    // UI-only state: current page (7-day window). Reset on month change via .id(monthDate)
    @State private var currentPage: Int = 0 // 默认指向最新页；向右滑动查看更早
    private let daysPerPage: Int = 7
    private let barSpacing: CGFloat = 8
    
    private var calendar: Calendar { Calendar.current }
    
    struct DayDatum: Identifiable {
        let id = UUID()
        let day: Int
        let income: Double
        let expense: Double
        let date: Date
    }
    
    private var chartData: [DayDatum] {
        // 如果选择了特定月份，使用该月份的数据；否则使用默认逻辑
        if let selectedMonth = selectedMonth {
            return monthlyChartData(for: selectedMonth)
        } else {
            return defaultChartData()
        }
    }
    
    private func monthlyChartData(for month: Date) -> [DayDatum] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: month)
        let today = calendar.startOfDay(for: Date())
        let isCurrentMonth = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
        
        // 计算结束日期：如果是当前月份，则到今天为止；否则到月末
        let endDate: Date
        if isCurrentMonth {
            endDate = today
        } else {
            // 获取该月的最后一天
            let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<32
            let lastDay = range.count
            endDate = calendar.date(byAdding: .day, value: lastDay - 1, to: startOfMonth) ?? startOfMonth
        }
        
        // 过滤该月份的交易
        let monthTransactions = store.transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: month, toGranularity: .month)
        }
        
        let expenseTx = monthTransactions.filter { $0.type == .expense }
        let incomeTx = monthTransactions.filter { $0.type == .income }
        
        // 按天聚合
        var expenseTotals: [Date: Double] = [:]
        var incomeTotals: [Date: Double] = [:]
        
        for t in expenseTx {
            let key = calendar.startOfDay(for: t.date)
            expenseTotals[key, default: 0] += t.amount
        }
        for t in incomeTx {
            let key = calendar.startOfDay(for: t.date)
            incomeTotals[key, default: 0] += t.amount
        }
        
        // 生成从月初到结束日期的每天数据
        var data: [DayDatum] = []
        var cursor = startOfMonth
        var day = 1
        
        while cursor <= endDate {
            let expense = expenseTotals[cursor] ?? 0
            let income = incomeTotals[cursor] ?? 0
            data.append(DayDatum(day: day, income: income, expense: expense, date: cursor))
            
            day += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDate
        }
        
        return data
    }
    
    private func defaultChartData() -> [DayDatum] {
        // Build a continuous daily series from at least (today-6) to today,
        // and extend earlier if there are older expenses to support paging right.
        let today = calendar.startOfDay(for: Date())
        let expenseTx = store.transactions.filter { $0.type == .expense }
        let incomeTx = store.transactions.filter { $0.type == .income }
        let earliestExpense = expenseTx.map { calendar.startOfDay(for: $0.date) }.min() ?? today
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let earliest = min(earliestExpense, sevenDaysAgo)
        
        // Aggregate expenses and incomes by day
        var expenseTotals: [Date: Double] = [:]
        var incomeTotals: [Date: Double] = [:]
        for t in expenseTx {
            let key = calendar.startOfDay(for: t.date)
            expenseTotals[key, default: 0] += t.amount
        }
        for t in incomeTx {
            let key = calendar.startOfDay(for: t.date)
            incomeTotals[key, default: 0] += t.amount
        }
        
        // Build array
        var data: [DayDatum] = []
        var cursor = earliest
        var idx = 1
        while cursor <= today {
            let exp = expenseTotals[cursor] ?? 0
            let inc = incomeTotals[cursor] ?? 0
            let displayDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: cursor) ?? cursor
            data.append(DayDatum(day: idx, income: inc, expense: exp, date: displayDate))
            idx += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? today
        }
        return data
    }
    
    private var maxValue: Double {
        let maxExpense = chartData.map { $0.expense }.max() ?? 0
        let maxIncome = chartData.map { $0.income }.max() ?? 0
        return max(max(maxExpense, maxIncome), 1)
    }
    
    private var pageCount: Int {
        guard !chartData.isEmpty else { return 1 }
        
        let total = chartData.count
        
        // 如果总数据不足7天，只需要1页
        if total <= daysPerPage {
            return 1
        }
        
        // 由于页面间有重叠（每页推进5天），重新计算页面数
        let stepSize = daysPerPage - 2 // 每页推进5天
        return max(1, Int(ceil(Double(total - daysPerPage) / Double(stepSize))) + 1)
    }
    
    private func pageRange(_ page: Int) -> Range<Int> {
        let total = chartData.count
        
        // 如果总数据不足7天，直接返回全部数据
        if total <= daysPerPage {
            return 0..<total
        }
        
        // 计算每页的步长（重叠2天，实际推进5天）
        let stepSize = daysPerPage - 2 // 每页推进5天，保持2天重叠
        
        // 计算当前页的结束位置（从最新数据开始算）
        let endIndex = total - page * stepSize
        
        // 确保每页显示7天数据
        let startIndex = max(0, endIndex - daysPerPage)
        let actualEndIndex = min(total, startIndex + daysPerPage)
        
        return startIndex..<actualEndIndex
    }
    
    private var lastPageIndex: Int { max(0, pageCount - 1) }
    
    var body: some View {
        VStack(spacing: 12) {
            if chartData.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                GeometryReader { geometry in
                    let axisWidth: CGFloat = 38
                    let axisSpacing: CGFloat = 6
                    let pageHeight: CGFloat = 200
                    let chartHeight: CGFloat = 160
                    let barsAreaWidth = max(0, geometry.size.width - axisWidth - axisSpacing)

                    HStack(alignment: .bottom, spacing: axisSpacing) {
                        // Gridlines overlay + paged bars region (left)
                        ZStack(alignment: .bottomLeading) {
                            YAxisGridLines(tickCount: 4)
                                .frame(height: chartHeight)
                                .padding(.bottom, pageHeight - chartHeight)
                                .allowsHitTesting(false)

                            TabView(selection: $currentPage) {
                                ForEach(0..<pageCount, id: \.self) { displayIndex in
                                    let internalPage = lastPageIndex - displayIndex
                                    BarChartPageView(
                                        chartData: Array(chartData[pageRange(internalPage)]),
                                        selectedDate: $selectedDate,
                                        maxValue: maxValue,
                                        barSpacing: barSpacing,
                                        calendar: calendar
                                    )
                                    .tag(displayIndex)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: pageHeight)
                        }
                        .frame(width: barsAreaWidth, height: pageHeight, alignment: .bottom)

                        // Fixed Y Axis (right) — align baseline with X-axis
                        YAxisView(maxValue: maxValue, tickCount: 4)
                            .frame(width: axisWidth, height: chartHeight, alignment: .bottom)
                            .padding(.bottom, pageHeight - chartHeight)
                    }
                }
                .frame(height: 200)
            }

            // 页脚：提示与页码（可选）
            HStack {
                Text("向右滑动展示更早数据")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            // 默认定位到最新页（今天往前 7 天）
            currentPage = lastPageIndex
        }
        .onChange(of: store.transactions.count) { _, _ in
            currentPage = lastPageIndex
        }
    }
}

// MARK: - BarChartPageView
struct BarChartPageView: View {
    let chartData: [ScrollableBarChartView.DayDatum]
    @Binding var selectedDate: Date?
    let maxValue: Double
    let barSpacing: CGFloat
    let calendar: Calendar
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let pageHeight: CGFloat = 200
            let chartHeight: CGFloat = 160
            let axisThickness: CGFloat = 1
            let labelsHeight: CGFloat = pageHeight - chartHeight - axisThickness
            let totalSpacing = barSpacing * max(0, CGFloat(chartData.count - 1))
            let availableWidth = geometry.size.width - totalSpacing
            let barWidth = chartData.isEmpty ? 0 : max(0, availableWidth / CGFloat(chartData.count))

            VStack(spacing: 0) {
                // Bars area aligned to bottom of chart
                HStack(spacing: barSpacing) {
                    ForEach(chartData, id: \.id) { datum in
                        BarItemView(
                            datum: datum,
                            selectedDate: $selectedDate,
                            maxValue: maxValue,
                            barWidth: barWidth,
                            calendar: calendar
                        )
                    }
                }
                .frame(height: chartHeight, alignment: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // X Axis line
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: axisThickness)

                // Date labels aligned under the bars (format: M/d)
                HStack(spacing: barSpacing) {
                    ForEach(chartData, id: \.id) { datum in
                        let isToday = calendar.isDateInToday(datum.date)
                        Text(formatDateLabel(datum.date))
                            .font(.system(size: 10, weight: isToday ? .semibold : .regular))
                            .foregroundColor(isToday ? .primary : .secondary)
                            .frame(width: barWidth)
                    }
                }
                .frame(height: labelsHeight)
            }
        }
        .frame(height: 200)
    }
}

// MARK: - BarItemView
struct BarItemView: View {
    let datum: ScrollableBarChartView.DayDatum
    @Binding var selectedDate: Date?
    let maxValue: Double
    let barWidth: CGFloat
    let calendar: Calendar
    
    private var isToday: Bool {
        calendar.isDateInToday(datum.date)
    }
    
    private var isSelected: Bool {
        guard let selectedDate = selectedDate else { return false }
        return calendar.isDate(datum.date, inSameDayAs: selectedDate)
    }
    
    var body: some View {
        // Two-column bars per day (expense left, income right)
        let maxBarHeight: CGFloat = 160
        let innerSpacing: CGFloat = min(4, barWidth * 0.25)
        let halfWidth: CGFloat = max(1, (barWidth - innerSpacing) / 2)
        let expenseRatio = maxValue > 0 ? datum.expense / maxValue : 0
        let incomeRatio  = maxValue > 0 ? datum.income  / maxValue : 0
        let expenseHeight = max(4, CGFloat(expenseRatio) * maxBarHeight)
        let incomeHeight  = max(4, CGFloat(incomeRatio)  * maxBarHeight)
        
        // Keep existing color logic (selected > today > normal)
        let expenseColor: Color = isSelected ? Color.red.opacity(0.9) : (isToday ? Color.red.opacity(0.7) : Color.red.opacity(0.5))
        let incomeColor: Color  = isSelected ? Color.blue.opacity(0.9) : (isToday ? Color.blue.opacity(0.7) : Color.blue.opacity(0.5))
        
        return HStack(spacing: innerSpacing) {
            // Expense (left)
            ZStack(alignment: .bottom) {
                if datum.expense > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(expenseColor)
                        .frame(width: halfWidth, height: expenseHeight)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: halfWidth, height: 4)
                }
            }
            .frame(width: halfWidth, height: maxBarHeight, alignment: .bottom)
            
            // Income (right)
            ZStack(alignment: .bottom) {
                if datum.income > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(incomeColor)
                        .frame(width: halfWidth, height: incomeHeight)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: halfWidth, height: 4)
                }
            }
            .frame(width: halfWidth, height: maxBarHeight, alignment: .bottom)
        }
        .frame(width: barWidth, height: maxBarHeight, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { selectedDate = datum.date }
        .accessibilityLabel("\(formatDate(datum.date))")
        .accessibilityValue("支出: \(String(format: "%.2f", datum.expense)), 收入: \(String(format: "%.2f", datum.income))")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
}

// MARK: - Y Axis + Gridlines
struct YAxisView: View {
    let maxValue: Double
    let tickCount: Int
    
    private func axisLabel(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        let text = nf.string(from: NSNumber(value: max(0, value))) ?? "0"
        return "¥" + text
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Vertical baseline on the LEFT of numbers
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            // Tick labels stacked vertically
            VStack(spacing: 0) {
                ForEach(0...tickCount, id: \.self) { i in
                    let value = maxValue * Double(tickCount - i) / Double(tickCount)
                    HStack {
                        Text(axisLabel(value))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if i < tickCount { Spacer(minLength: 0) }
                }
            }
        }
        .padding(.leading, 2)
    }
}

struct YAxisGridLines: View {
    let tickCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Draw gridlines for tick levels above baseline to avoid double-drawing X-axis
            ForEach(0..<tickCount, id: \.self) { i in
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Income Bar View
struct IncomeBarView: View {
    let income: Double
    let maxValue: Double
    let isToday: Bool
    let isSelected: Bool
    
    private var barHeight: CGFloat {
        let ratio = maxValue > 0 ? income / maxValue : 0
        return max(2, ratio * 75) // Income占上半部分
    }
    
    private var fillColor: Color {
        if isSelected {
            return Color.blue.opacity(0.9)
        } else if isToday {
            return Color.blue.opacity(0.7)
        } else {
            return Color.blue.opacity(0.5)
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .frame(height: barHeight)
    }
}

// MARK: - Expense Bar View
struct ExpenseBarView: View {
    let expense: Double
    let maxValue: Double
    let isToday: Bool
    let isSelected: Bool
    
    private var barHeight: CGFloat {
        let ratio = maxValue > 0 ? expense / maxValue : 0
        return max(2, ratio * 75) // Expense占下半部分
    }
    
    private var fillColor: Color {
        if isSelected {
            return Color.red.opacity(0.9)
        } else if isToday {
            return Color.red.opacity(0.7)
        } else {
            return Color.red.opacity(0.5)
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .frame(height: barHeight)
    }
}

// MARK: - Empty Bar View
struct EmptyBarView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 2)
    }
}

// MARK: - Calendar Extension
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Picker("月份", selection: Binding(
                    get: { normalizedSelectedMonth },
                    set: { selectedMonth = $0 }
                )) {
                    ForEach(availableMonths, id: \.self) { month in
                        Text(monthFormatter.string(from: month))
                            .tag(month)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter
    }
}

// MARK: - 月度概览组件
struct MonthlyOverviewView: View {
    let income: Double
    let expense: Double
    let balance: Double
    let balancePercentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("✨ 月度概览")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("本月总收入:")
                        .font(.system(size: 14))
                        .foregroundColor(.brown)
                    Spacer()
                    Text("¥\(String(format: "%.2f", income))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("本月总支出:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("¥\(String(format: "%.2f", expense))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("本月余额:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥\(String(format: "%.2f", balance))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(balance >= 0 ? .blue : .red)
                        Text("(\(String(format: "%.1f", balancePercentage))%)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

// MARK: - 消费趋势组件
struct ConsumptionTrendView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    @Binding var selectedDate: Date?
    
    private var calendar: Calendar { Calendar.current }
    
    private var defaultDisplayDate: Date {
        // 当前月显示今天，否则显示该月最后一天
        if calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) {
            return calendar.startOfDay(for: Date())
        } else {
            let startOfMonth = calendar.startOfMonth(for: selectedMonth)
            let range = calendar.range(of: .day, in: .month, for: selectedMonth) ?? 1..<32
            let lastDay = range.count
            let lastDate = calendar.date(byAdding: .day, value: lastDay - 1, to: startOfMonth) ?? selectedMonth
            return calendar.startOfDay(for: lastDate)
        }
    }
    
    private var displayDate: Date { selectedDate.map(calendar.startOfDay(for:)) ?? defaultDisplayDate }
    
    private var dayIncome: Double {
        let day = displayDate
        return store.transactions
            .filter { $0.type == .income && calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var dayExpense: Double {
        let day = displayDate
        return store.transactions
            .filter { $0.type == .expense && calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 消费趋势")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            // 选中/默认日期的当日支出与收入
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(Color.blue.opacity(0.9)).frame(width: 6, height: 6)
                    Text("收入: ¥\(String(format: "%.2f", dayIncome))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.9)).frame(width: 6, height: 6)
                    Text("支出: ¥\(String(format: "%.2f", dayExpense))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, 2)
            
            ScrollableBarChartView(store: store, selectedMonth: selectedMonth, selectedDate: $selectedDate)
                .frame(height: 260)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

// MARK: - 支出类别分布组件
struct ExpenseCategoryDistributionView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    
    private var categoryExpenses: [(category: Category, amount: Double, percentage: Double)] {
        let calendar = Calendar.current
        let monthTransactions = store.transactions.filter { transaction in
            transaction.type == .expense && 
            calendar.isDate(transaction.date, equalTo: selectedMonth, toGranularity: .month)
        }
        
        var categoryTotals: [Category: Double] = [:]
        for transaction in monthTransactions {
            categoryTotals[transaction.category, default: 0] += transaction.amount
        }
        
        let totalExpense = categoryTotals.values.reduce(0, +)
        
        return categoryTotals.compactMap { (category, amount) in
            let percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0
            return (category: category, amount: amount, percentage: percentage)
        }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💰 支出类别分布")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if categoryExpenses.isEmpty {
                Text("暂无支出数据")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(categoryExpenses.prefix(5), id: \.category.id) { item in
                        HStack {
                            Text("\(item.category.icon) \(item.category.name)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(String(format: "%.1f", item.percentage))%")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("¥\(String(format: "%.2f", item.amount))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

// MARK: - 智能提示组件
struct SmartTipView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date
    
    private var smartTip: String {
        let calendar = Calendar.current
        let monthTransactions = store.transactions.filter { transaction in
            transaction.type == .expense && 
            calendar.isDate(transaction.date, equalTo: selectedMonth, toGranularity: .month)
        }
        
        var categoryTotals: [String: Double] = [:]
        for transaction in monthTransactions {
            categoryTotals[transaction.category.name, default: 0] += transaction.amount
        }
        
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        
        if let topCategory = sortedCategories.first {
            let totalExpense = categoryTotals.values.reduce(0, +)
            let percentage = (topCategory.value / totalExpense) * 100
            
            if percentage > 40 {
                return "💡 提示：\(topCategory.key)支出较高（\(String(format: "%.1f", percentage))%），建议适当控制此类支出。"
            } else if percentage > 30 {
                return "💡 提示：\(topCategory.key)是主要支出项目，可考虑寻找更优惠的选择。"
            } else {
                return "💡 提示：支出分布较为均衡，继续保持理性消费。"
            }
        } else {
            return "💡 提示：本月暂无支出记录，继续保持良好的理财习惯。"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(smartTip)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Helpers
private func formatMonthYYYYMM(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy/MM"
    return f.string(from: date)
}

// MARK: - Income Details Section
struct IncomeDetailsView: View {
    let income: Double
    
    var body: some View {
        HStack {
            RollingNumberView(
                value: income,
                font: .system(size: 24, weight: .bold, design: .rounded),
                textColor: .primary,
                prefix: "¥"
            )
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
    }
}

// MARK: - Cost and Balance Progress Section
struct CostBalanceProgressView: View {
    let expense: Double
    let balance: Double
    let totalIncome: Double
    
    private var expenseRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(expense / totalIncome, 1.0)
    }
    
    private var balanceRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(max((totalIncome - expense) / totalIncome, 0), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部标签（仅文案）
            HStack {
                Text("花销")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("余额")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // 血条样式的进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条（总收入）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .frame(height: 28)
                    
                    HStack(spacing: 0) {
                        // Cost部分（淡红色）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.6))
                            .frame(width: geometry.size.width * expenseRatio, height: 28)
                            .animation(.easeInOut(duration: 0.8), value: expenseRatio)
                        
                        // Balance部分（淡蓝色）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: geometry.size.width * balanceRatio, height: 28)
                            .animation(.easeInOut(duration: 0.8), value: balanceRatio)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 数字显示（保留在进度条下方）
            HStack {
                RollingNumberView(
                    value: expense,
                    font: .system(size: 12, weight: .regular, design: .rounded),
                    textColor: .red,
                    prefix: "¥",
                    digitWidth: 12,
                    decimalPointWidth: 6,
                    separatorWidth: 6
                )
                
                Spacer()
                
                RollingNumberView(
                    value: balance,
                    font: .system(size: 12, weight: .regular, design: .rounded),
                    textColor: balance >= 0 ? .blue : .red,
                    prefix: "¥",
                    digitWidth: 12,
                    decimalPointWidth: 6,
                    separatorWidth: 6
                )
            }
        }
        // Removed Pow changeEffects to avoid multi-updates per frame warnings
    }
}

// MARK: - Month Switcher Section
struct MonthSwitcherView: View {
    @Binding var selectedPeriod: Int
    
    private let periodOptions = ["本月", "上个月"]
    
    var body: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(0..<periodOptions.count, id: \.self) { index in
                Text(periodOptions[index])
                    .tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .animation(.easeInOut(duration: 0.3), value: selectedPeriod)
        .padding(.top, 4)
    }
}


// MARK: - Rolling Number Animation Components

struct DigitRollingView: View {
    let digit: Int
    let font: Font
    let textColor: Color
    
    @State private var displayedDigit: Int = 0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Current digit
            Text("\(displayedDigit)")
                .font(font)
                .foregroundColor(textColor)
                .offset(y: offset)
            
            // Next digit (for animation)
            if displayedDigit != digit {
                Text("\(digit)")
                    .font(font)
                    .foregroundColor(textColor)
                    .offset(y: offset + (digit > displayedDigit ? 20 : -20))
            }
        }
        .clipped()
        .onChange(of: digit) { _, newDigit in
            // 使用 Pow 的 boing 效果进行更有趣的过渡
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                let direction: CGFloat = newDigit > displayedDigit ? -20 : 20
                offset = direction
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                displayedDigit = newDigit
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
        }
        .onAppear {
            displayedDigit = digit
        }
        // Removed extra changeEffect to prevent overlapping state updates
    }
}

struct RollingNumberView: View {
    let value: Double
    let font: Font
    let textColor: Color
    let prefix: String
    let showDecimals: Bool
    // Configurable widths
    let digitWidth: CGFloat
    let decimalPointWidth: CGFloat
    let separatorWidth: CGFloat
    let currencyUnitWidth: CGFloat
    
    @State private var animatedValue: Double = 0
    
    init(
        value: Double,
        font: Font = .system(size: 18, weight: .bold, design: .rounded),
        textColor: Color = .primary,
        prefix: String = "",
        showDecimals: Bool = true,
        digitWidth: CGFloat = 16,
        decimalPointWidth: CGFloat = 8,
        separatorWidth: CGFloat = 8,
        currencyUnitWidth: CGFloat = 20
    ) {
        self.value = value
        self.font = font
        self.textColor = textColor
        self.prefix = prefix
        self.showDecimals = showDecimals
        self.digitWidth = digitWidth
        self.decimalPointWidth = decimalPointWidth
        self.separatorWidth = separatorWidth
        self.currencyUnitWidth = currencyUnitWidth
    }
    
    private var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.maximumFractionDigits = showDecimals ? 2 : 0
        formatter.minimumFractionDigits = showDecimals ? 2 : 0
        
        let formatted = formatter.string(from: NSNumber(value: abs(animatedValue))) ?? "0"
        let sign = animatedValue < 0 ? "-" : ""
        return "\(sign)\(prefix)\(formatted)"
    }
    
    private var digits: [String] {
        return formattedValue.compactMap { char in
            return String(char)
        }
    }
    
    // Removed previousValue tracking to reduce redundant state changes
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(digits.enumerated()), id: \.offset) { index, character in
                if character.first?.isNumber == true {
                    DigitRollingView(
                        digit: Int(character) ?? 0,
                        font: font,
                        textColor: textColor
                    )
                    .frame(width: digitWidth) // 数字宽度（可配置）
                } else {
                    Text(character)
                        .font(font)
                        .foregroundColor(textColor)
                        .frame(width: {
                            // 根据字符类型分配不同宽度
                            if character == "." { return decimalPointWidth }
                            if character == "¥" || character == "$" { return currencyUnitWidth } // 货币符号需要更宽
                            if character == "," { return separatorWidth } // 千分位分隔符
                            return 12 // 其他符号默认宽度
                        }())
                }
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = newValue
            }
        }
        .onAppear {
            animatedValue = value
        }
        // Removed Pow changeEffects to avoid overlapping onChange(Date) triggers
    }
}

#Preview {
    MonthlySummaryView(store: TransactionStore())
}

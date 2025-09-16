//
//  BarChartView.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - ScrollableBarChartView: Main scrollable bar chart component
//  - BarChartPageView: Individual page view for chart pagination
//  - BarItemView: Individual bar components
//  - YAxisView: Y-axis labels and ticks
//  - YAxisGridLines: Grid lines for the chart
//  - Bar-related helper components and views
//

import SwiftUI
import Foundation

// MARK: - Scrollable Bar Chart View
struct ScrollableBarChartView: View {
    @ObservedObject var store: TransactionStore
    let selectedMonth: Date?
    @Binding var selectedDate: Date?
    let viewMode: ChartViewMode
    
    init(store: TransactionStore, selectedMonth: Date? = nil, selectedDate: Binding<Date?> = .constant(nil), viewMode: ChartViewMode = .week) {
        self.store = store
        self.selectedMonth = selectedMonth
        self._selectedDate = selectedDate
        self.viewMode = viewMode
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
        // 根据视图模式和选择的月份返回不同的数据
        if let selectedMonth = selectedMonth {
            switch viewMode {
            case .week:
                return weeklyChartData(for: selectedMonth)
            case .month:
                return monthlyChartData(for: selectedMonth)
            }
        } else {
            return defaultChartData()
        }
    }
    
    private func weeklyChartData(for month: Date) -> [DayDatum] {
        // 周视图：7天分页，支持滑动查看更早数据（保持原有逻辑）
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
    
    private func monthlyChartData(for month: Date) -> [DayDatum] {
        // 月视图：展示当月所有天数的数据，从月初到今天/月末，不分页
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
        
        // 月视图：显示所有数据，不分页
        if viewMode == .month {
            return 1
        }
        
        // 周视图：7天分页逻辑
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
        
        // 月视图：返回所有数据
        if viewMode == .month {
            return 0..<total
        }
        
        // 周视图：7天分页逻辑
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
                Text(viewMode == .week ? "向右滑动展示更早数据" : "展示当月所有数据")
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
        .onChange(of: viewMode) { _, _ in
            // 当视图模式改变时，重置到最新页
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
        DateFormatter.onlyDay.string(from: date)
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
                        let isSelected = selectedDate != nil && calendar.isDate(datum.date, inSameDayAs: selectedDate!)
                        
                        Text(formatDateLabel(datum.date))
                            .font(.system(size: 10, weight: isSelected ? .bold : (isToday ? .semibold : .regular)))
                            .foregroundColor(isSelected ? .primary : (isToday ? .primary : .secondary))
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
        .onTapGesture {
            if isSelected {
                selectedDate = nil
            } else {
                selectedDate = datum.date
            }
        }
        .accessibilityLabel("\(formatDate(datum.date))")
        .accessibilityValue("支出: \(String(format: "%.2f", datum.expense)), 收入: \(String(format: "%.2f", datum.income))")
    }
    
    private func formatDate(_ date: Date) -> String {
        DateFormatter.monthDayChinese.string(from: date)
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

// MARK: - Individual Bar Components
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

struct EmptyBarView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 2)
    }
}


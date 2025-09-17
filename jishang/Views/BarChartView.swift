//
//  BarChartView.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - ScrollableBarChartView: Swift Charts-based bar chart component supporting
//    week/month modes, right-swipe to previous weeks, and tap-to-select.
//

import SwiftUI
import Foundation
import Charts

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
    
    // iOS17 的 X 轴选择绑定（与 selectedDate 同步）
    @State private var xSelection: Date? = nil
    // iOS17 的横向滚动位置（必须为非可选类型，单位与 X 轴 Plottable 一致，这里是 Date）
    @State private var xScrollPosition: Date = Date()
    // 周滚动吸附：防抖定时器与时间戳（用于判断滚动结束）
    @State private var lastScrollEventAt: Date = .distantPast
    @State private var snapWorkItem: DispatchWorkItem?
    private let maxWeeksBack: Int = 4 // 最多查看前四周
    private var calendar: Calendar { Calendar.current }

    struct DayDatum: Identifiable {
        let id = UUID()
        let day: Int
        let income: Double
        let expense: Double
        let date: Date
    }
    
    // MARK: Data Builders
    // 将给定时间范围内的交易聚合为连续的日序列（无数据的日期填 0）
    private func buildDailySeries(from startDate: Date, to endDate: Date) -> [DayDatum] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        // 过滤时间范围内的交易
        let rangeTx = store.transactions.filter { t in
            let d = calendar.startOfDay(for: t.date)
            return d >= start && d <= end
        }
        let expenseTx = rangeTx.filter { $0.type == .expense }
        let incomeTx = rangeTx.filter { $0.type == .income }

        // 按天聚合
        var expenseTotals: [Date: Double] = [:]
        var incomeTotals: [Date: Double] = [:]
        for t in expenseTx { expenseTotals[calendar.startOfDay(for: t.date), default: 0] += t.amount }
        for t in incomeTx  { incomeTotals [calendar.startOfDay(for: t.date), default: 0] += t.amount }

        // 生成序列
        var data: [DayDatum] = []
        var cursor = start
        var idx = 1
        while cursor <= end {
            let expense = expenseTotals[cursor] ?? 0
            let income  = incomeTotals[cursor]  ?? 0
            data.append(DayDatum(day: idx, income: income, expense: expense, date: cursor))
            idx += 1
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? end
        }
        return data
    }

    // 月视图：当月从 1 号到今天（若非本月则到月末）。仅 1 页
    private func monthlyPage(for month: Date) -> [DayDatum] {
        let start = calendar.startOfMonth(for: month)
        let today = calendar.startOfDay(for: Date())
        let isCurrentMonth = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
        let end: Date
        if isCurrentMonth {
            end = today
        } else {
            end = calendar.endOfMonth(for: month)
        }
        return buildDailySeries(from: start, to: end)
    }

    // iOS17 滚动轴使用的整体域（周视图：最近 5 周）
    private var weekOverallRange: (start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())
        let end = calendar.endOfWeek(for: today)
        let start = calendar.date(byAdding: .day, value: -7 * maxWeeksBack, to: calendar.startOfWeek(for: today)) ?? end
        return (start, end)
    }
    
    private var weekOverallData: [DayDatum] {
        buildDailySeries(from: weekOverallRange.start, to: weekOverallRange.end)
    }
    
    private var monthOverallRange: (start: Date, end: Date) {
        let target = selectedMonth ?? Date()
        let start = calendar.startOfMonth(for: target)
        let isCurrentMonth = calendar.isDate(target, equalTo: Date(), toGranularity: .month)
        let end = isCurrentMonth ? calendar.startOfDay(for: Date()) : calendar.endOfMonth(for: target)
        return (start, end)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            SwiftChartsBar()
                .frame(height: 200)
            // 页脚：提示
            HStack {
                Text(viewMode == .week ? "横向滚动查看上/下周（最多前四周）" : "展示当月从 1 日至今天")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            if let sel = selectedDate { xSelection = sel } else { xSelection = calendar.startOfDay(for: Date()) }
            // 初始将可见窗口靠近整体域的末端（最新一周 / 当月末）
            xScrollPosition = (viewMode == .week) ? weekOverallRange.end : monthOverallRange.end
        }
        .onChange(of: viewMode) { _, _ in
            xSelection = selectedDate ?? calendar.startOfDay(for: Date())
            xScrollPosition = (viewMode == .week) ? weekOverallRange.end : monthOverallRange.end
        }
        .onChange(of: selectedMonth) { _, _ in
            // 切换月份时，月视图滚动到该月末（或今天）
            if viewMode == .month { xScrollPosition = monthOverallRange.end }
        }
        // 周滚动吸附：在横向滚动停止后，将位置吸附到最近的周起点
        .onChange(of: xScrollPosition) { _, newValue in
            guard viewMode == .week else { return }
            snapWorkItem?.cancel()
            let scheduledAt = Date()
            lastScrollEventAt = scheduledAt
            let work = DispatchWorkItem {
                if lastScrollEventAt == scheduledAt {
                    var target = calendar.startOfWeek(for: newValue)
                    // clamp 到合法范围（保证整周可见）
                    let minStart = weekOverallRange.start
                    let maxStart = calendar.date(byAdding: .day, value: -6, to: weekOverallRange.end) ?? weekOverallRange.end
                    if target < minStart { target = minStart }
                    if target > maxStart { target = maxStart }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        xScrollPosition = target
                    }
                }
            }
            snapWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}

// MARK: - Swift Charts Implementation

private extension ScrollableBarChartView {
    @ViewBuilder
    func SwiftChartsBar() -> some View {
        let overallRange = (viewMode == .week) ? weekOverallRange : monthOverallRange
        if viewMode == .week {
            WeekChart(data: weekOverallData, range: overallRange)
        } else {
            MonthChart(data: monthlyPage(for: selectedMonth ?? Date()), range: overallRange)
        }
    }

    @ViewBuilder
    private func WeekChart(data: [DayDatum], range: (start: Date, end: Date)) -> some View {
        let yMax = calculateMaxValue(for: data)
        let baseChart = createBaseChart(data: data)
        let configuredChart = configureChart(baseChart, yMax: yMax, range: range)
        let scrollableChart = configureScrolling(configuredChart)
        addSelectionHandlers(scrollableChart)
    }

    private func calculateMaxValue(for data: [DayDatum]) -> Double {
        let expenseValues = data.map { $0.expense }
        let incomeValues = data.map { $0.income }
        let maxExpense: Double = expenseValues.max() ?? 0
        let maxIncome: Double = incomeValues.max() ?? 0
        let maxValue = max(maxExpense, maxIncome)
        return max(maxValue, 1)
    }

    private func createBaseChart(data: [DayDatum]) -> some View {
        let barContent = barMarks(for: data)
        let selectionContent = selectionMark()
        return Chart {
            barContent
            selectionContent
        }
    }

    private func configureChart<V: View>(_ chart: V, yMax: Double, range: (start: Date, end: Date)) -> some View {
        chart
            .chartLegend(.hidden)
            .chartYScale(domain: 0...yMax)
            .chartXScale(domain: range.start...range.end)
            .chartXAxis { dayAxisMarks() }
    }

    private func configureScrolling<V: View>(_ chart: V) -> some View {
        chart
            .chartScrollableAxes(.horizontal)
            .chartScrollTargetBehavior(.valueAligned(unit: 1))
            .chartXVisibleDomain(length: 60 * 60 * 24 * 7)
            .chartXSelection(value: $xSelection)
            .chartScrollPosition(x: $xScrollPosition)
    }

    private func addSelectionHandlers<V: View>(_ chart: V) -> some View {
        chart
            .onChange(of: xSelection) { _, newValue in
                if let date = newValue {
                    selectedDate = calendar.startOfDay(for: date)
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                xSelection = newValue
            }
    }

    @ViewBuilder
    private func MonthChart(data: [DayDatum], range: (start: Date, end: Date)) -> some View {
        let yMax = calculateMaxValue(for: data)
        let baseChart = createBaseChart(data: data)
        let configuredChart = configureChart(baseChart, yMax: yMax, range: range)
        let selectableChart = addMonthSelection(configuredChart)
        addSelectionHandlers(selectableChart)
    }

    private func addMonthSelection<V: View>(_ chart: V) -> some View {
        chart.chartXSelection(value: $xSelection)
    }

    private func dayAxisMarks() -> some AxisContent {
        AxisMarks(values: .stride(by: .day)) { value in
            AxisGridLine().foregroundStyle(Color(.systemGray5))
            AxisTick().foregroundStyle(Color(.systemGray4))
            AxisValueLabel {
                let date = value.as(Date.self)
                let label = date.map { DateFormatter.onlyDay.string(from: $0) } ?? ""
                let isToday = date.map { calendar.isDateInToday($0) } ?? false
                let selected = date.flatMap { d in selectedDate.map { calendar.isDate(d, inSameDayAs: $0) } } ?? false
                let weight: Font.Weight = selected ? .bold : (isToday ? .semibold : .regular)
                let color: Color = (selected || isToday) ? .primary : .secondary
                Text(label).font(.system(size: 10, weight: weight)).foregroundColor(color)
            }
        }
    }

    @ChartContentBuilder
    private func barMarks(for data: [DayDatum]) -> some ChartContent {
        expenseBarMarks(for: data)
        incomeBarMarks(for: data)
    }

    @ChartContentBuilder
    private func expenseBarMarks(for data: [DayDatum]) -> some ChartContent {
        ForEach(data, id: \.id) { day in
            let style = barColor(type: .expense, day: day)
            BarMark(x: .value("日期", day.date), y: .value("金额", day.expense))
                .position(by: .value("类型", "支出"))
                .foregroundStyle(style)
                .cornerRadius(4)
        }
    }

    @ChartContentBuilder
    private func incomeBarMarks(for data: [DayDatum]) -> some ChartContent {
        ForEach(data, id: \.id) { day in
            let style = barColor(type: .income, day: day)
            BarMark(x: .value("日期", day.date), y: .value("金额", day.income))
                .position(by: .value("类型", "收入"))
                .foregroundStyle(style)
                .cornerRadius(4)
        }
    }

    @ChartContentBuilder
    private func selectionMark() -> some ChartContent {
        if let sel = xSelection {
            selectionRuleMark(for: sel)
        }
    }

    @ChartContentBuilder
    private func selectionRuleMark(for date: Date) -> some ChartContent {
        let exp = store.dailyExpense(for: date)
        let inc = store.dailyIncome(for: date)
        let lineStyle = StrokeStyle(lineWidth: 1)
        let foregroundColor = Color(.systemGray3)

        RuleMark(x: .value("选中", date))
            .lineStyle(lineStyle)
            .foregroundStyle(foregroundColor)
            .annotation(position: .top) {
                ChartTooltipView(date: date, expense: exp, income: inc)
            }
    }

    struct ChartTooltipView: View {
        let date: Date
        let expense: Double
        let income: Double
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(DateFormatter.monthDayChinese.string(from: date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red.opacity(0.8)).frame(width: 6, height: 6)
                        Text(expense.currencyFormattedTwoDecimal)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue.opacity(0.8)).frame(width: 6, height: 6)
                        Text(income.currencyFormattedTwoDecimal)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.white, radius: 3, x: 0, y: 1)
        }
    }

    enum BarType { case income, expense }

    func barColor(type: BarType, day: DayDatum) -> Color {
        let isToday = calendar.isDateInToday(day.date)
        let isSelected = selectedDate.map { calendar.isDate(day.date, inSameDayAs: $0) } ?? false
        let base: Color = (type == .expense) ? .red : .blue
        let opacity: Double = isSelected ? 0.9 : (isToday ? 0.7 : 0.5)
        return base.opacity(opacity)
    }
}

// Note: Legacy manual bar components removed due to migration to Swift Charts.

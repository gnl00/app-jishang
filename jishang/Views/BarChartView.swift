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
    // 周视图分页（TabView）当前页索引：0=最早，maxWeeksBack=最新
    @State private var weekPageIndex: Int = 0
    // 防抖标志：避免双向状态绑定循环
    @State private var isUpdatingSelection: Bool = false
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
            HStack {
                Text(viewMode == .week ? "左右滑动查看前/后周数据" : "展示当月数据")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            isUpdatingSelection = true
            if let sel = selectedDate { xSelection = sel } else { xSelection = calendar.startOfDay(for: Date()) }
            // 初始定位：周视图对齐到"周起点"，月视图到"该月末/今天"
            if viewMode == .week {
                let anchor = selectedDate ?? weekOverallRange.end
                xScrollPosition = calendar.startOfWeek(for: anchor)
                // 初始化周分页索引：按 oldest->newest 排列，默认指向包含 anchor 的那页
                weekPageIndex = initialWeekPageIndex(anchor: anchor)
            } else {
                xScrollPosition = monthOverallRange.end
            }
            DispatchQueue.main.async {
                isUpdatingSelection = false
            }
        }
        .onChange(of: viewMode) { _, _ in
            isUpdatingSelection = true
            xSelection = selectedDate ?? calendar.startOfDay(for: Date())
            if viewMode == .week {
                let anchor = selectedDate ?? weekOverallRange.end
                xScrollPosition = calendar.startOfWeek(for: anchor)
                weekPageIndex = initialWeekPageIndex(anchor: anchor)
            } else {
                xScrollPosition = monthOverallRange.end
            }
            DispatchQueue.main.async {
                isUpdatingSelection = false
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            // 切换月份时，月视图滚动到该月末（或今天）
            if viewMode == .month { xScrollPosition = monthOverallRange.end }
        }
        .onChange(of: weekPageIndex) { _, _ in
            // 周分页切换时，如果当前选中的日期不在新页范围内，则清除选中，避免显示跨页的 tooltip
            guard viewMode == .week else { return }
            let pages = weeklyPages()
            guard weekPageIndex >= 0 && weekPageIndex < pages.count else { return }
            let r = pages[weekPageIndex].range
            if let sel = xSelection {
                let d = calendar.startOfDay(for: sel)
                if d < r.start || d > r.end { xSelection = nil }
            }
        }
        // 采用 .paging 内置行为，无需手写吸附
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
        // 使用 TabView 做 5 周分页：oldest -> newest；默认定位到包含 anchor 的页
        let pages = weeklyPages()
        let yMax = calculateMaxValue(for: pages.flatMap { $0.data })
        TabView(selection: $weekPageIndex) {
            ForEach(0..<pages.count, id: \.self) { idx in
                let page = pages[idx]
                let baseChart = createBaseChart(data: page.data)
                let ticks = (0...6).compactMap { calendar.date(byAdding: .day, value: $0, to: page.range.start) }
                // 扩展 X 轴 domain 两侧各 12 小时，避免首尾刻度/标签被边界压缩
                let startPad = calendar.date(byAdding: .hour, value: -12, to: page.range.start) ?? page.range.start
                let endPad = calendar.date(byAdding: .hour, value: 12, to: page.range.end) ?? page.range.end
                let configuredChart = configureChart(baseChart, yMax: yMax, range: (startPad, endPad), xAxisDays: ticks)
                let selectable = addMonthSelection(configuredChart) // 复用选择绑定
                addSelectionHandlers(selectable)
                    .tag(idx)
                    .frame(height: 200)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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

    // 构建 5 周分页（oldest -> newest），每页 7 天；与 selectedMonth 无关
    private func weeklyPages() -> [(data: [DayDatum], range: (start: Date, end: Date))] {
        let today = calendar.startOfDay(for: Date())
        let startOfThisWeek = calendar.startOfWeek(for: today)
        let earliest = calendar.date(byAdding: .day, value: -7 * maxWeeksBack, to: startOfThisWeek) ?? startOfThisWeek
        var pages: [(data: [DayDatum], range: (start: Date, end: Date))] = []
        for offset in 0...maxWeeksBack { // oldest -> newest
            let start = calendar.date(byAdding: .day, value: 7 * offset, to: earliest) ?? earliest
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            pages.append((data: buildDailySeries(from: start, to: end), range: (start, end)))
        }
        return pages
    }

    // 根据 anchor（selectedDate 或 today）计算初始周分页索引
    private func initialWeekPageIndex(anchor: Date) -> Int {
        let anchorWeekStart = calendar.startOfWeek(for: anchor)
        let today = calendar.startOfDay(for: Date())
        let startOfThisWeek = calendar.startOfWeek(for: today)
        let earliest = calendar.date(byAdding: .day, value: -7 * maxWeeksBack, to: startOfThisWeek) ?? startOfThisWeek
        let days = calendar.dateComponents([.day], from: earliest, to: anchorWeekStart).day ?? (7 * maxWeeksBack)
        let index = max(0, min(maxWeeksBack, days / 7))
        return index
    }

    private func configureChart<V: View>(_ chart: V, yMax: Double, range: (start: Date, end: Date), xAxisDays: [Date]? = nil) -> some View {
        chart
            .chartLegend(.hidden)
            .chartYScale(domain: 0...yMax)
            .chartXScale(domain: range.start...range.end)
            // 为避免首尾两天的柱贴边，给绘图区添加左右内边距
            .chartPlotStyle { plot in
                plot.padding(.leading, 12).padding(.trailing, 12)
            }
            .chartXAxis { dayAxisMarks(days: xAxisDays) }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
    }

    private func configureScrolling<V: View>(_ chart: V) -> some View {
        chart
            .chartScrollableAxes(.horizontal)
            .chartScrollTargetBehavior(.paging)
            .chartXVisibleDomain(length: 60 * 60 * 24 * 7)
            .chartXSelection(value: $xSelection)
            .chartScrollPosition(x: $xScrollPosition)
    }

    private func addSelectionHandlers<V: View>(_ chart: V) -> some View {
        chart
            .onChange(of: xSelection) { _, newValue in
                guard !isUpdatingSelection else { return }
                if let date = newValue {
                    isUpdatingSelection = true
                    selectedDate = calendar.startOfDay(for: date)
                    // 延迟重置标志，避免同帧内的反向更新
                    DispatchQueue.main.async {
                        isUpdatingSelection = false
                    }
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                guard !isUpdatingSelection else { return }
                isUpdatingSelection = true
                xSelection = newValue
                // 延迟重置标志，避免同帧内的反向更新
                DispatchQueue.main.async {
                    isUpdatingSelection = false
                }
            }
    }

    @ViewBuilder
    private func MonthChart(data: [DayDatum], range: (start: Date, end: Date)) -> some View {
        let yMax = calculateMaxValue(for: data)
        let baseChart = createBaseChart(data: data)
        // 轻度扩展 X 轴 domain，避免最后一天刻度被边界压缩（对月视图也有帮助）
        let startPad = calendar.date(byAdding: .hour, value: -12, to: range.start) ?? range.start
        let endPad = calendar.date(byAdding: .hour, value: 12, to: range.end) ?? range.end
        let configuredChart = configureChart(baseChart, yMax: yMax, range: (startPad, endPad), xAxisDays: nil)
        let selectableChart = addMonthSelection(configuredChart)
        addSelectionHandlers(selectableChart)
    }

    private func addMonthSelection<V: View>(_ chart: V) -> some View {
        chart.chartXSelection(value: $xSelection)
    }

    private func dayAxisMarks(days: [Date]? = nil) -> some AxisContent {
        if let explicitDays = days {
            AxisMarks(values: explicitDays) { value in
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
        } else {
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
            .annotation(position: .automatic) {
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
                    .fill(.white)
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

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
        // 使用单Chart + 原生滚动吸附，替代TabView方案
        let allWeeksData = weekOverallData // 显示所有5周数据
        let yMax = calculateMaxValue(for: allWeeksData)

        let baseChart = Chart {
            barMarks(for: allWeeksData)  // 显示所有数据
            selectionMark()              // 单一selection状态，无冲突
        }

        let configuredChart = baseChart
            .chartLegend(.hidden)
            .chartYScale(domain: 0...yMax)
            .chartXScale(domain: weekOverallRange.start...weekOverallRange.end)
            .chartXAxis { dayAxisMarks() }
            .chartYAxis {
                AxisMarks(position: .leading)
            }

        let scrollableChart = configuredChart
            // 核心：原生滚动吸附配置
            .chartScrollableAxes(.horizontal)
            .chartScrollTargetBehavior(.valueAligned(unit: 7 * 24 * 60 * 60)) // 按周吸附（7天）
            .chartXVisibleDomain(length: 7 * 24 * 60 * 60) // 显示一周宽度
            .chartScrollPosition(x: $xScrollPosition)
            .chartXSelection(value: $xSelection)

        let interactiveChart = scrollableChart
            // 增强手势体验
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        snapToNearestWeek(dragValue: value)
                    }
            )

        interactiveChart
            // 状态管理
            .onChange(of: xSelection) { _, newValue in
                guard !isUpdatingSelection else { return }
                if let date = newValue {
                    isUpdatingSelection = true
                    selectedDate = calendar.startOfDay(for: date)
                    DispatchQueue.main.async {
                        isUpdatingSelection = false
                    }
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                guard !isUpdatingSelection else { return }
                isUpdatingSelection = true
                xSelection = newValue
                DispatchQueue.main.async {
                    isUpdatingSelection = false
                }
            }
    }

    private func calculateMaxValue(for data: [DayDatum]) -> Double {
        let expenseValues = data.map { $0.expense }
        let incomeValues = data.map { $0.income }
        let maxExpense: Double = expenseValues.max() ?? 0
        let maxIncome: Double = incomeValues.max() ?? 0
        let maxValue = max(maxExpense, maxIncome)
        return max(maxValue, 1)
    }




    @ViewBuilder
    private func MonthChart(data: [DayDatum], range: (start: Date, end: Date)) -> some View {
        let yMax = calculateMaxValue(for: data)
        let startPad = calendar.date(byAdding: .hour, value: -12, to: range.start) ?? range.start
        let endPad = calendar.date(byAdding: .hour, value: 12, to: range.end) ?? range.end

        Chart {
            barMarks(for: data)
            selectionMark()
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...yMax)
        .chartXScale(domain: startPad...endPad)
        .chartPlotStyle { plot in
            plot.padding(.leading, 12).padding(.trailing, 12)
        }
        .chartXAxis { dayAxisMarks() }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXSelection(value: $xSelection)
        .onChange(of: xSelection) { _, newValue in
            guard !isUpdatingSelection else { return }
            if let date = newValue {
                isUpdatingSelection = true
                selectedDate = calendar.startOfDay(for: date)
                DispatchQueue.main.async {
                    isUpdatingSelection = false
                }
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            guard !isUpdatingSelection else { return }
            isUpdatingSelection = true
            xSelection = newValue
            DispatchQueue.main.async {
                isUpdatingSelection = false
            }
        }
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

    // MARK: - Week Chart Snap Algorithm
    private func snapToNearestWeek(dragValue: DragGesture.Value) {
        let threshold: CGFloat = 50 // 滑动阈值
        let currentDate = Date(timeIntervalSince1970: xScrollPosition.timeIntervalSince1970)
        let currentWeekStart = calendar.startOfWeek(for: currentDate)

        var targetWeekStart = currentWeekStart

        if dragValue.translation.width > threshold {
            // 向右滑动，显示上一周
            targetWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
        } else if dragValue.translation.width < -threshold {
            // 向左滑动，显示下一周
            targetWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        }

        // 边界检查：确保不超出weekOverallRange范围
        let minWeekStart = weekOverallRange.start
        let maxWeekStart = calendar.date(byAdding: .day, value: -6, to: weekOverallRange.end) ?? weekOverallRange.end

        if targetWeekStart < minWeekStart {
            targetWeekStart = minWeekStart
        } else if targetWeekStart > maxWeekStart {
            targetWeekStart = maxWeekStart
        }

        // 平滑动画切换到目标周
        withAnimation(.easeInOut(duration: 0.3)) {
            xScrollPosition = targetWeekStart
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

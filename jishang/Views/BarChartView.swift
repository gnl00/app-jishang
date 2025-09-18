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
    // 防抖标志：避免双向状态绑定循环
    @State private var isUpdatingSelection: Bool = false
    // 当前显示的周偏移量：0=本周, -1=上周, -2=前两周...
    @State private var currentWeekOffset: Int = 0
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

    // 当前显示周的数据（只包含7天）
    private var currentWeekData: [DayDatum] {
        let today = calendar.startOfDay(for: Date())
        let thisWeekStart = calendar.startOfWeek(for: today)
        let targetWeekStart = calendar.date(byAdding: .day, value: 7 * currentWeekOffset, to: thisWeekStart) ?? thisWeekStart
        let targetWeekEnd = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) ?? targetWeekStart
        return buildDailySeries(from: targetWeekStart, to: targetWeekEnd)
    }

    // 当前显示周的时间范围
    private var currentWeekRange: (start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())
        let thisWeekStart = calendar.startOfWeek(for: today)
        let targetWeekStart = calendar.date(byAdding: .day, value: 7 * currentWeekOffset, to: thisWeekStart) ?? thisWeekStart
        let targetWeekEnd = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) ?? targetWeekStart
        return (targetWeekStart, targetWeekEnd)
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
            initializeSelection()
        }
        .onChange(of: viewMode) { _, _ in
            initializeSelection()
        }
        .onChange(of: selectedDate) { _, newValue in
            if viewMode == .week {
                updateWeekOffsetForSelectedDate(newValue)
            }
        }
    }
}

// MARK: - Helper Functions

private extension ScrollableBarChartView {

    // 初始化选择状态
    private func initializeSelection() {
        isUpdatingSelection = true
        xSelection = selectedDate ?? calendar.startOfDay(for: Date())
        DispatchQueue.main.async {
            isUpdatingSelection = false
        }
    }

    // 根据选中日期更新周偏移量
    private func updateWeekOffsetForSelectedDate(_ date: Date?) {
        guard let date = date else { return }
        let today = calendar.startOfDay(for: Date())
        let thisWeekStart = calendar.startOfWeek(for: today)
        let selectedWeekStart = calendar.startOfWeek(for: date)

        let weeksDiff = calendar.dateComponents([.weekOfYear], from: selectedWeekStart, to: thisWeekStart).weekOfYear ?? 0
        let newOffset = -weeksDiff
        let clampedOffset = max(-maxWeeksBack, min(0, newOffset))

        if clampedOffset != currentWeekOffset {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentWeekOffset = clampedOffset
            }
        }
    }

    // 处理周视图手势切换
    private func handleWeekSwipe(translation: CGSize) {
        let threshold: CGFloat = 50
        var newOffset = currentWeekOffset

        if translation.width > threshold {
            // 向右滑动，显示上一周
            newOffset = currentWeekOffset - 1
        } else if translation.width < -threshold {
            // 向左滑动，显示下一周
            newOffset = currentWeekOffset + 1
        } else {
            return // 滑动距离不足，不切换
        }

        // 边界检查
        let clampedOffset = max(-maxWeeksBack, min(0, newOffset))
        if clampedOffset != currentWeekOffset {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentWeekOffset = clampedOffset
            }
        }
    }
}

// MARK: - Swift Charts Implementation

private extension ScrollableBarChartView {
    @ViewBuilder
    func SwiftChartsBar() -> some View {
        if viewMode == .week {
            WeekChart(data: currentWeekData, range: currentWeekRange)
        } else {
            MonthChart(data: monthlyPage(for: selectedMonth ?? Date()), range: monthOverallRange)
        }
    }

    @ViewBuilder
    private func WeekChart(data: [DayDatum], range: (start: Date, end: Date)) -> some View {
        let yMax = calculateMaxValue(for: data)
        // 轻度扩展 X 轴 domain，避免首尾柱贴边
        let startPad = calendar.date(byAdding: .hour, value: -12, to: range.start) ?? range.start
        let endPad = calendar.date(byAdding: .hour, value: 12, to: range.end) ?? range.end

        Chart {
            barMarks(for: data)
            selectionMark()
        }
        .chartLegend(.hidden)
        .chartForegroundStyleScale([
            "支出": .red.opacity(0.8),
            "收入": .blue.opacity(0.8)
        ])
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
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    handleWeekSwipe(translation: value.translation)
                }
        )
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
        let baseMax = max(maxValue, 1)

        // 添加 15% 的缓冲空间，确保柱子不会超出图表边界
        return baseMax * 1.15
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
        .chartForegroundStyleScale([
            "支出": .red.opacity(0.8),
            "收入": .blue.opacity(0.8)
        ])
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
        ForEach(data, id: \.id) { day in
            // 支出柱
            BarMark(x: .value("日期", day.date), y: .value("金额", day.expense))
                .foregroundStyle(by: .value("类型", "支出"))
                .position(by: .value("类型", "支出"), axis: .horizontal, span: .ratio(1))
                .cornerRadius(4)
                .offset(x: 10)
            
            // 收入柱
            BarMark(x: .value("日期", day.date), y: .value("金额", day.income))
                .foregroundStyle(by: .value("类型", "收入"))
                .position(by: .value("类型", "收入"), axis: .horizontal, span: .ratio(1))
                .cornerRadius(4)
        }
    }

    @ChartContentBuilder
    private func selectionMark() -> some ChartContent {
        if let sel = xSelection {
            selectionRuleMark(for: sel)
        } else {
            // 当没有选择时，显示今天的标记（用于调试）
            let today = calendar.startOfDay(for: Date())
            selectionRuleMark(for: today)
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
            .annotation(position: .leading) {
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

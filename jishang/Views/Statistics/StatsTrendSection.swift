//
//  StatsTrendSection.swift
//  jishang
//

import SwiftUI
import Charts
import Pow

// MARK: - 趋势分析（合并收入/支出/结余/累计结余）
struct StatsTrendSection: View {
    @ObservedObject var store: TransactionStore
    let timeRange: StatisticsView.TimeRange

    enum Metric: String, CaseIterable, Identifiable {
        case income = "收入"
        case expense = "支出"
        case net = "月结余"
        case cumulativeNet = "累计结余"
        var id: String { rawValue }
    }

    @State private var metric: Metric = .expense
    @State private var mainType: MainFilterType = .expense
    @State private var monthsSlice: Int = 12
    @State private var chartMode: ChartMode = .bar
    @State private var xSelection: Date? = nil
    @Namespace private var metricNS
    @Namespace private var sliceNS
    @Namespace private var mainNS
    // 明细列表已移除，不再需要开关

    enum ChartMode: String, CaseIterable { case bar, line }

    private var monthsAvailableByRange: Int {
        switch timeRange {
        case .allTime: return 12
        case .last12Months: return 12
        case .last6Months: return 6
        case .last3Months: return 3
        }
    }

    private var monthsToDisplay: Int { min(monthsSlice, monthsAvailableByRange) }

    private var monthList: [Date] {
        let calendar = Calendar.current
        let startOfCurrentMonth = calendar.startOfMonth(for: Date())
        return (0..<monthsToDisplay).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: startOfCurrentMonth)
        }.reversed()
    }

    private struct RowDatum: Identifiable {
        let id = UUID()
        let month: Date
        let value: Double
        let mom: Double?
    }

    private var rows: [RowDatum] {
        var cumulative: Double = 0
        var data: [RowDatum] = []
        var previousValue: Double? = nil
        for m in monthList {
            let income = store.monthlyIncome(for: m)
            let expense = store.monthlyExpense(for: m)
            let net = income - expense

            let current: Double
            switch metric {
            case .income: current = income
            case .expense: current = expense
            case .net: current = net
            case .cumulativeNet: cumulative += net; current = cumulative
            }

            let momChange: Double?
            if let prev = previousValue, abs(prev) > 0.01 {
                momChange = ((current - prev) / abs(prev)) * 100
            } else {
                momChange = nil
            }
            previousValue = current
            data.append(RowDatum(month: Calendar.current.startOfMonth(for: m), value: current, mom: momChange))
        }
        return data
    }

    private var maxAbsValue: Double { max(rows.map { abs($0.value) }.max() ?? 1, 1) }

    private var insightText: String? {
        guard rows.count >= 2 else { return nil }
        if let maxRow = rows.max(by: { abs($0.value) < abs($1.value) }) {
            let formatter = DateFormatter(); formatter.dateFormat = "M月"
            return "\(formatter.string(from: maxRow.month))波动较大，建议关注主要类别"
        }
        return nil
    }

    // Top 类别贡献（相对上月的变化贡献）
    private var topCategoryInsightText: String? {
        // 选择波动最大的行
        guard let targetRow = rows.filter({ $0.mom != nil }).max(by: { abs($0.mom ?? 0) < abs($1.mom ?? 0) }) else { return nil }
        let calendar = Calendar.current
        let month = targetRow.month
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: month) else { return nil }

        // 根据当前指标选择类型（净额/累计结余使用支出说明更直观）
        let type: TransactionType = (metric == .income) ? .income : .expense

        let curTotals = store.monthlyCategoryTotals(for: month, type: type)
        let prevTotals = store.monthlyCategoryTotals(for: prevMonth, type: type)

        // 计算各类差异
        struct Diff { let category: Category; let delta: Double }
        let allCats = Set(curTotals.keys).union(prevTotals.keys)
        var diffs: [Diff] = []
        for c in allCats {
            let cur = curTotals[c] ?? 0
            let prev = prevTotals[c] ?? 0
            let delta = cur - prev
            if abs(delta) > 0.001 { diffs.append(Diff(category: c, delta: delta)) }
        }
        guard !diffs.isEmpty else { return nil }

        // 总变化量（分母用绝对值和，避免正负抵消）
        let totalChange = diffs.map { abs($0.delta) }.reduce(0, +)
        guard totalChange > 0 else { return nil }

        // 取前2个贡献最大的类别
        let top2 = diffs.sorted { abs($0.delta) > abs($1.delta) }.prefix(2)
        let parts = top2.map { d -> String in
            let pct = Int(round(abs(d.delta) / totalChange * 100))
            let sign = d.delta >= 0 ? "+" : "-"
            return "\(d.category.icon)\(d.category.name) \(sign)\(pct)%"
        }
        if parts.isEmpty { return nil }
        return "Top类别贡献: " + parts.joined(separator: "，")
    }

    private var availableMetricChips: [Metric] { [] } // 移除子指标行

    private var mainOptions: [MainFilterType] { [.income, .expense] }

    private var accentColor: Color {
        switch mainType {
        case .income: return Color.blue.opacity(0.8)
        case .expense: return Color.red.opacity(0.8)
        case .all: return Color.accentColor
        }
    }

    private var monthsSliceLabel: String {
        switch monthsSlice {
        case 3: return "近3月"
        case 6: return "近6月"
        default: return "近12月"
        }
    }

    var body: some View {
        StatsSectionCard {
            VStack {
            // 单行工具条：主筛选 + 模式 + 范围选择（下拉）
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(mainOptions, id: \.self) { t in
                            TrendMainButton(
                                title: t.rawValue,
                                isSelected: mainType == t,
                                color: accentColor
                            ) {
                                handleMainTypeSelection(t)
                            }
                        }
                    }
                    .padding(.leading, 2)
                }
                Spacer(minLength: 8)
//                Picker("", selection: $chartMode) {
//                    Text("柱").tag(ChartMode.bar)
//                    Text("线").tag(ChartMode.line)
//                }
//                .pickerStyle(.segmented)
//                .frame(width: 100)

                // 时间范围下拉选择（替代 SubFilterButton）
                // 参考 StatisticsView 时间范围的样式：使用 Menu + 胶囊标签
                Menu {
                    ForEach([3,6,12], id: \.self) { n in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                monthsSlice = min(n, monthsAvailableByRange)
                            }
                        }) {
                            HStack {
                                Text(n == 3 ? "近3月" : n == 6 ? "近6月" : "近12月")
                                if monthsSlice == n { Image(systemName: "checkmark") }
                            }
                        }
                        .disabled(n > monthsAvailableByRange)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(monthsSliceLabel)
                            .font(.system(size: 12, weight: .medium))
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 12)

            // 图表
            TrendChart()
                .frame(height: 220)
                .overlay(alignment: .top) {
                    if let sel = xSelection, let tip = tooltipData(for: sel) {
                        TooltipBubbleView(
                            monthText: DateFormatter.yearMonth.string(from: tip.month),
                            valueText: tip.value.currencyFormattedInt,
                            momText: tip.mom.flatMap { m in (m > 0 ? "↑" : "↓") + abs(m).percentFormattedInt },
                            topInsight: tip.topInsight
                        ).padding(.top, 6)
                    }
                }
            Spacer()
            if let insight = insightText {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill").foregroundColor(.blue.opacity(0.7)).font(.system(size: 12))
                    Text(insight).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                }
            }
            Spacer()
            if let topInsight = topCategoryInsightText {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill").foregroundColor(.yellow.opacity(0.8)).font(.system(size: 12))
                    Text(topInsight).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                }
            }
            }
        }
    }

    @ViewBuilder
    private func TrendChart() -> some View {
        let data = rows
        Chart {
            ForEach(data) { r in
                if chartMode == .bar {
                    BarMark(
                        x: .value("月份", r.month),
                        y: .value("数值", r.value)
                    )
                    .foregroundStyle(accentColor)
                    .cornerRadius(4)
                } else {
                    LineMark(
                        x: .value("月份", r.month),
                        y: .value("数值", r.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accentColor)
                    PointMark(
                        x: .value("月份", r.month),
                        y: .value("数值", r.value)
                    )
                    .symbolSize(20)
                    .foregroundStyle(accentColor)
                }
            }
            if let xSelection { RuleMark(x: .value("选中", xSelection)) }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine().foregroundStyle(Color(.systemGray5))
                AxisTick().foregroundStyle(Color(.systemGray4))
                AxisValueLabel(format: .dateTime.year().month())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXSelection(value: $xSelection)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in plot.padding(.leading, 8).padding(.trailing, 8) }
    }

    // MARK: - Handlers & Subviews
    private func handleMainTypeSelection(_ t: MainFilterType) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            mainType = t
            switch t {
            case .income:
                metric = .income; chartMode = .bar
            case .expense:
                metric = .expense; chartMode = .bar
            case .all:
                metric = .expense; chartMode = .bar
            }
        }
    }

    private struct TrendMainButton: View {
        let title: String
        let isSelected: Bool
        let color: Color
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isSelected ? color : Color(.systemGray6))
                    )
            }
        }
    }

    // MARK: - Tooltip helpers
    private func tooltipData(for date: Date) -> (month: Date, value: Double, mom: Double?, topInsight: String?)? {
        let cal = Calendar.current
        guard let row = rows.first(where: { cal.isDate($0.month, inSameDayAs: date) }) else { return nil }
        return (month: row.month, value: row.value, mom: row.mom, topInsight: topCategoryInsight(for: row.month))
    }

    private func topCategoryInsight(for month: Date) -> String? {
        let calendar = Calendar.current
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: month) else { return nil }
        let type: TransactionType = (metric == .income) ? .income : .expense
        let curTotals = store.monthlyCategoryTotals(for: month, type: type)
        let prevTotals = store.monthlyCategoryTotals(for: prevMonth, type: type)
        struct Diff { let category: Category; let delta: Double }
        let allCats = Set(curTotals.keys).union(prevTotals.keys)
        var diffs: [Diff] = []
        for c in allCats {
            let cur = curTotals[c] ?? 0
            let prev = prevTotals[c] ?? 0
            let delta = cur - prev
            if abs(delta) > 0.001 { diffs.append(Diff(category: c, delta: delta)) }
        }
        guard !diffs.isEmpty else { return nil }
        let totalChange = diffs.map { abs($0.delta) }.reduce(0, +)
        guard totalChange > 0 else { return nil }
        let top2 = diffs.sorted { abs($0.delta) > abs($1.delta) }.prefix(2)
        let parts = top2.map { d -> String in
            let pct = Int(round(abs(d.delta) / totalChange * 100))
            let sign = d.delta >= 0 ? "+" : "-"
            return "\(d.category.icon)\(d.category.name) \(sign)\(pct)%"
        }
        return parts.isEmpty ? nil : parts.joined(separator: "，")
    }

    private struct TooltipBubbleView: View {
        let monthText: String
        let valueText: String
        let momText: String?
        let topInsight: String?
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(monthText).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                    Text(valueText).font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                    if let momText { Text(momText).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary) }
                }
                if let topInsight {
                    Text("Top: " + topInsight)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            .frame(maxWidth: 280, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatsTrendHeaderRow: View {
    private func column(_ title: String, alignment: Alignment = .trailing) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
    var body: some View {
        HStack(spacing: 12) {
            column("月份", alignment: .leading)
            column("数值")
            column("环比")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatsTrendDataRow: View {
    let month: Date
    let value: Double
    let maxAbsValue: Double
    let change: Double?

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy年M月"; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Text(Self.monthFormatter.string(from: month))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(value >= 0 ? Color.blue.opacity(0.7) : Color.red.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(min(abs(value) / maxAbsValue, 1)), height: 8)
                }
            }
            .frame(height: 8)

            Text(value.currencyFormattedInt)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if let change = change {
                if abs(change) <= 5 {
                    Text("持平")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    let icon = change > 0 ? "arrow.up" : "arrow.down"
                    let color: Color = change > 0 ? Color(red: 118/255, green: 176/255, blue: 141/255) : Color(red: 218/255, green: 119/255, blue: 119/255)
                    HStack(spacing: 4) {
                        Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(color)
                        Text(abs(change).percentFormattedInt).font(.system(size: 11, weight: .medium)).foregroundColor(color).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

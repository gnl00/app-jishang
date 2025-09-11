//
//  MonthlyStatisticsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI
import Pow

struct MonthlyStatisticsView: View {
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
            DailyExpenseChartView(store: store, monthDate: selectedDate)
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
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                onShowDetails?()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Daily Expense Bar Chart Sheet
struct DailyExpenseChartView: View {
    @ObservedObject var store: TransactionStore
    let monthDate: Date
    
    private var calendar: Calendar { Calendar.current }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
    }
    
    private var dailyExpenses: [Double] {
        var totals = Array(repeating: 0.0, count: daysInMonth)
        for t in store.transactions where t.type == .expense {
            if calendar.isDate(t.date, equalTo: monthDate, toGranularity: .month) {
                let day = calendar.component(.day, from: t.date)
                if (1...daysInMonth).contains(day) {
                    totals[day - 1] += t.amount
                }
            }
        }
        return totals
    }
    
    private var dailyIncomes: [Double] {
        var totals = Array(repeating: 0.0, count: daysInMonth)
        for t in store.transactions where t.type == .income {
            if calendar.isDate(t.date, equalTo: monthDate, toGranularity: .month) {
                let day = calendar.component(.day, from: t.date)
                if (1...daysInMonth).contains(day) {
                    totals[day - 1] += t.amount
                }
            }
        }
        return totals
    }
    
    private var maxExpense: Double { dailyExpenses.max() ?? 0 }
    private var maxIncome: Double { dailyIncomes.max() ?? 0 }
    private var maxValue: Double { max(maxExpense, maxIncome) }
    private var totalExpense: Double { dailyExpenses.reduce(0, +) }
    private var totalIncome: Double { dailyIncomes.reduce(0, +) }
    private var hasAnyExpense: Bool { store.transactions.contains { $0.type == .expense } }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: monthDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("月度消费数据")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.top)
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("月度余额")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatMonthYYYYMM(Date()))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    // Monthly total expense in big rolling number
                    RollingNumberView(
                        value: store.monthlyIncome(for: Date()) - store.monthlyExpense(for: Date()),
                        font: .system(size: 28, weight: .semibold, design: .rounded),
                        textColor: .primary,
                        prefix: "¥ ",
                        showDecimals: false,
                        digitWidth: 18,
                        decimalPointWidth: 10,
                        separatorWidth: 10,
                        currencyUnitWidth: 18
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                )
                
                if !hasAnyExpense {
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
                } else {
                    // Seven-day paged bar chart (last 7 days from today, swipe right for earlier)
                    ScrollableBarChartView(store: store)
                        .frame(height: 260)
                        .padding(.vertical, 4)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
}

struct ScrollableBarChartView: View {
    @ObservedObject var store: TransactionStore
    
    // UI-only state: current page (7-day window). Reset on month change via .id(monthDate)
    @State private var currentPage: Int = 0 // 默认指向最新页；向右滑动查看更早
    private let daysPerPage: Int = 7
    private let barSpacing: CGFloat = 8
    
    private var calendar: Calendar { Calendar.current }
    
    private struct DayDatum: Identifiable {
        let id = UUID()
        let day: Int
        let income: Double
        let expense: Double
        let date: Date
    }
    
    private var chartData: [DayDatum] {
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
        return Int(ceil(Double(chartData.count) / Double(daysPerPage)))
    }
    
    private func pageRange(_ page: Int) -> Range<Int> {
        // TabView 页序：0 = 最早，last = 最新。
        // 每页以“末尾对齐”的 7 天窗口，确保最新页总是今天往前 7 天。
        let total = chartData.count
        let last = lastPageIndex
        let indexFromEnd = max(0, last - page)
        let end = max(0, min(total, total - indexFromEnd * daysPerPage))
        let start = max(0, end - daysPerPage)
        return start..<end
    }
    
    private var lastPageIndex: Int { max(0, pageCount - 1) }
    
    var body: some View {
        VStack(spacing: 12) {
            // 可分页（每页7天）的柱状图，同时展示支出与收入
            GeometryReader { geometry in
                let totalSpacing = CGFloat(daysPerPage - 1) * barSpacing
                let barWidth = max(8, (geometry.size.width - totalSpacing - 24) / CGFloat(daysPerPage))
                let maxBarHeight: CGFloat = 160
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        let range = pageRange(page)
                        let today = calendar.startOfDay(for: Date())
                        HStack(alignment: .bottom, spacing: barSpacing) {
                            // 如果是最新页且数据不足7天，前置补齐以显示今天往前的完整7天日期
                            if range.count < daysPerPage && page == lastPageIndex {
                                let missing = daysPerPage - range.count
                                ForEach(0..<missing, id: \.self) { slot in
                                    let startDate = calendar.date(byAdding: .day, value: -(daysPerPage - 1), to: today) ?? today
                                    let date = calendar.date(byAdding: .day, value: slot, to: startDate) ?? startDate
                                    VStack(spacing: 6) {
                                        HStack(spacing: 3) {
                                            ZStack(alignment: .bottom) {}
                                                .frame(width: (barWidth-3)/2, height: maxBarHeight)
                                            ZStack(alignment: .bottom) {}
                                                .frame(width: (barWidth-3)/2, height: maxBarHeight)
                                        }
                                        Text(formatDateLabel(date))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary.opacity(0.6))
                                            .frame(width: barWidth)
                                    }
                                }
                            }
                            ForEach(Array(range), id: \.self) { index in
                                let item = chartData[index]
                                let expenseValue = item.expense
                                let incomeValue = item.income
                                let expenseHeight = CGFloat(expenseValue / maxValue) * maxBarHeight
                                let incomeHeight = CGFloat(incomeValue / maxValue) * maxBarHeight
                                let isCurrentMonth = calendar.isDate(item.date, equalTo: Date(), toGranularity: .month)
                                let isCurrentDate = calendar.isDate(item.date, inSameDayAs: Date())
                                let innerSpacing: CGFloat = 3
                                let halfWidth = (barWidth - innerSpacing) / 2
                                
                                VStack(spacing: 6) {
                                    HStack(spacing: innerSpacing) {
                                        // Expense (left)
                                        ZStack(alignment: .bottom) {
                                            if expenseValue > 0 {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(isCurrentDate ? Color.red.opacity(0.75) : Color.red.opacity(0.35))
                                                    .frame(width: halfWidth, height: max(4, expenseHeight))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .stroke((isCurrentMonth ? Color.red.opacity(0.25) : Color.red.opacity(0.2)), lineWidth: 1)
                                                    )
                                            } else {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.12))
                                                    .frame(width: halfWidth, height: 4)
                                            }
                                        }
                                        .frame(width: halfWidth, height: maxBarHeight, alignment: .bottom)
                                        
                                        // Income (right)
                                        ZStack(alignment: .bottom) {
                                            if incomeValue > 0 {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(isCurrentDate ? Color.blue.opacity(0.8) : Color.blue.opacity(0.45))
                                                    .frame(width: halfWidth, height: max(4, incomeHeight))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .stroke((isCurrentMonth ? Color.blue.opacity(0.25) : Color.blue.opacity(0.2)), lineWidth: 1)
                                                    )
                                            } else {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.12))
                                                    .frame(width: halfWidth, height: 4)
                                            }
                                        }
                                        .frame(width: halfWidth, height: maxBarHeight, alignment: .bottom)
                                    }
                                    .frame(width: barWidth, height: maxBarHeight, alignment: .bottom)
                                    
                                    Text(formatDateLabel(item.date))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isCurrentMonth ? .secondary : .secondary.opacity(0.6))
                                        .frame(width: barWidth)
                                }
                                .accessibilityLabel("\(formatDate(item.date))")
                                .accessibilityValue("支出: \(String(format: "%.2f", expenseValue)), 收入: \(String(format: "%.2f", incomeValue))")
                            }
                            // 若非最新页数据不足7天，在右侧补空位以保持节奏
                            if range.count < daysPerPage && page != lastPageIndex {
                                ForEach(0..<(daysPerPage - range.count), id: \.self) { _ in
                                    VStack(spacing: 6) {
                                        HStack(spacing: 3) {
                                            ZStack(alignment: .bottom) {}
                                                .frame(width: (barWidth-3)/2, height: maxBarHeight)
                                            ZStack(alignment: .bottom) {}
                                                .frame(width: (barWidth-3)/2, height: maxBarHeight)
                                        }
                                        Text("").frame(width: barWidth)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: 200)
            
            // 页脚：提示与页码（可选）
            HStack {
                Text("向右滑动展示更早数据")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
//                Spacer()
//                if pageCount > 1 {
//                    Text("\(currentPage + 1)/\(pageCount)")
//                        .font(.system(size: 12))
//                        .foregroundColor(.secondary)
//                }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date).lowercased()
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
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
        // Removed Pow changeEffect to avoid overlapping per-frame updates
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
    MonthlyStatisticsView(store: TransactionStore())
}

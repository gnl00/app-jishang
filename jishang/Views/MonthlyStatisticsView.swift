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
        VStack(spacing: 16) {
            // Section 1: Header with title and expand arrow
            HeaderSectionView(isExpanded: $isExpanded)
            
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
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Header Section with Title and Expand Arrow
struct HeaderSectionView: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack {
            Text("Monthly Statistics")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.1), value: isExpanded)
            }
        }
        .padding(.vertical, 4)
    }
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
        .changeEffect(.glow, value: income)
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
            // Boss血条样式的进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条（总收入）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 44)
                    
                    HStack(spacing: 0) {
                        // Cost部分（淡红色）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.6))
                            .frame(width: geometry.size.width * expenseRatio, height: 44)
                            .animation(.easeInOut(duration: 0.8), value: expenseRatio)
                        
                        // Balance部分（淡蓝色）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: geometry.size.width * balanceRatio, height: 44)
                            .animation(.easeInOut(duration: 0.8), value: balanceRatio)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 金额显示
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    RollingNumberView(
                        value: expense,
                        font: .system(size: 12, weight: .regular, design: .rounded),
                        textColor: .red,
                        prefix: "¥"
                    )
                    Text("expense")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    RollingNumberView(
                        value: balance,
                        font: .system(size: 12, weight: .regular, design: .rounded),
                        textColor: balance >= 0 ? .blue : .red,
                        prefix: "¥"
                    )
                    Text("balance")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .changeEffect(.wiggle, value: expense)
        .changeEffect(.glow, value: balance)
    }
}

// MARK: - Month Switcher Section
struct MonthSwitcherView: View {
    @Binding var selectedPeriod: Int
    
    private let periodOptions = ["current month", "last month"]
    
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
        // 添加数字变化时的摆动效果
        .changeEffect(.wiggle, value: digit)
    }
}

struct RollingNumberView: View {
    let value: Double
    let font: Font
    let textColor: Color
    let prefix: String
    let showDecimals: Bool
    
    @State private var animatedValue: Double = 0
    @State private var previousValue: Double = 0
    
    init(value: Double, font: Font = .system(size: 18, weight: .bold, design: .rounded), textColor: Color = .primary, prefix: String = "", showDecimals: Bool = true) {
        self.value = value
        self.font = font
        self.textColor = textColor
        self.prefix = prefix
        self.showDecimals = showDecimals
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
    
    // 判断是否有变化来触发发光效果
    private var hasChanged: Bool {
        return value != previousValue
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(digits.enumerated()), id: \.offset) { index, character in
                if character.first?.isNumber == true {
                    DigitRollingView(
                        digit: Int(character) ?? 0,
                        font: font,
                        textColor: textColor
                    )
                    .frame(width: 16) // 数字宽度
                } else {
                    Text(character)
                        .font(font)
                        .foregroundColor(textColor)
                        .frame(width: {
                            // 根据字符类型分配不同宽度
                            if character == "." { return 8 }
                            if character == "¥" || character == "$" { return 20 } // 货币符号需要更宽
                            if character == "," { return 8 } // 千分位分隔符
                            return 12 // 其他符号默认宽度
                        }())
                }
            }
        }
        .onChange(of: value) { _, newValue in
            previousValue = animatedValue
            
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = newValue
            }
        }
        .onAppear {
            animatedValue = value
            previousValue = value
        }
        // 添加 Pow 动画效果
        .changeEffect(.shine, value: value) // 数值变化时的闪光效果
        .changeEffect(.glow, value: hasChanged) // 变化时的发光效果
    }
}

#Preview {
    MonthlyStatisticsView(store: TransactionStore())
}

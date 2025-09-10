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
    
    private var currentMonthIncome: Double {
        store.monthlyIncome(for: Date())
    }
    
    private var currentMonthExpense: Double {
        store.monthlyExpense(for: Date())
    }
    
    private var balance: Double {
        currentMonthIncome - currentMonthExpense
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                // Monthly Expense (Left) - 1/4 width
                StatisticSection(
                    title: "本月支出",
                    amount: currentMonthExpense,
                    backgroundColor: Color.clear,
                    textColor: .red,
                    cornerRadius: [.topLeft, .bottomLeft]
                )
                .frame(width: geometry.size.width * 0.25)
                .transition(.slide)
                .changeEffect(.glow, value: currentMonthExpense)
                
                // Monthly Balance (Center) - 2/4 width  
                BalanceSection(
                    title: "本月结余",
                    amount: balance,
                    backgroundColor: Color.clear,
                    textColor: balance >= 0 ? .green : .primary
                )
                .frame(width: geometry.size.width * 0.5)
                .transition(.scale)
                .changeEffect(.glow, value: balance)
                
                // Monthly Income (Right) - 1/4 width
                StatisticSection(
                    title: "本月收入",
                    amount: currentMonthIncome,
                    backgroundColor: Color.clear,
                    textColor: .blue,
                    cornerRadius: [.topRight, .bottomRight]
                )
                .frame(width: geometry.size.width * 0.25)
                .transition(.slide)
                .changeEffect(.glow, value: currentMonthIncome)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                .changeEffect(.glow, value: balance != 0)
        )
        .frame(height: 120)
        .padding(.horizontal)
        .transition(.slide.combined(with: .opacity).animation(.spring(response: 0.6, dampingFraction: 0.7)))
    }
}

struct StatisticSection: View {
    let title: String
    let amount: Double
    let backgroundColor: Color
    let textColor: Color
    let cornerRadius: UIRectCorner
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .changeEffect(.wiggle, value: title)
            
            RollingNumberView(
                value: amount,
                font: .system(size: 18, weight: .bold, design: .rounded),
                textColor: textColor
            )
            .changeEffect(.shine, value: amount)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedCorner(radius: 12, corners: cornerRadius))
        .changeEffect(.wiggle, value: amount)
    }
}

struct BalanceSection: View {
    let title: String
    let amount: Double
    let backgroundColor: Color
    let textColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .changeEffect(.wiggle, value: title)
            
            RollingNumberView(
                value: amount,
                font: .system(size: 20, weight: .bold, design: .rounded),
                textColor: textColor
            )
            .changeEffect(.glow, value: amount > 0)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(backgroundColor)
        .changeEffect(.wiggle, value: amount)
        .scaleEffect(amount > 0 ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: amount > 0)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
        .onChange(of: digit) { newDigit in
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
                    .frame(width: 12) // Fixed width for consistent spacing
                } else {
                    Text(character)
                        .font(font)
                        .foregroundColor(textColor)
                        .frame(width: character == "." ? 6 : 8)
                }
            }
        }
        .onChange(of: value) { newValue in
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

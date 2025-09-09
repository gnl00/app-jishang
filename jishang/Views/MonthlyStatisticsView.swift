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
                .changeEffect(.wiggle, value: currentMonthExpense)
                
                // Monthly Balance (Center) - 2/4 width  
                BalanceSection(
                    title: "本月结余",
                    amount: balance,
                    backgroundColor: Color.clear,
                    textColor: balance >= 0 ? .green : .primary
                )
                .frame(width: geometry.size.width * 0.5)
                .transition(.scale)
                .changeEffect(.wiggle, value: balance)
                
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
                .changeEffect(.wiggle, value: currentMonthIncome)
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
            
            Text(amount.currencyFormatted)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
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
            
            Text(amount.currencyFormatted)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
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

#Preview {
    MonthlyStatisticsView(store: TransactionStore())
}

//
//  MonthlyStatisticsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

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
                
                // Monthly Balance (Center) - 2/4 width  
                BalanceSection(
                    title: "本月结余",
                    amount: balance,
                    backgroundColor: Color.clear,
                    textColor: balance >= 0 ? .green : .primary
                )
                .frame(width: geometry.size.width * 0.5)
                
                // Monthly Income (Right) - 1/4 width
                StatisticSection(
                    title: "本月收入",
                    amount: currentMonthIncome,
                    backgroundColor: Color.clear,
                    textColor: .blue,
                    cornerRadius: [.topRight, .bottomRight]
                )
                .frame(width: geometry.size.width * 0.25)
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
        )
        .frame(height: 120)
        .padding(.horizontal)
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
            
            Text(amount.currencyFormatted)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedCorner(radius: 12, corners: cornerRadius))
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
            
            Text(amount.currencyFormatted)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(backgroundColor)
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
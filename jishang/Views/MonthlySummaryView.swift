//
//  MonthlySummaryView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//  
//  Contains:
//  - MonthlySummaryView: Monthly summary card for home page
//  - MonthSwitcherView: Month switcher component
//

import SwiftUI
import Pow

struct MonthlySummaryView: View {
    @ObservedObject var store: TransactionStore
    @State private var selectedPeriod = 0
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
    
    private var previousMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private var previousMonthBalance: Double {
        let income = store.monthlyIncome(for: previousMonthDate)
        let expense = store.monthlyExpense(for: previousMonthDate)
        return income - expense
    }
    
    private var balanceChange: Double {
        balance - previousMonthBalance
    }
    
    private var balanceChangePercent: Double? {
        guard previousMonthBalance != 0 else { return nil }
        return (balanceChange / abs(previousMonthBalance)) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            headerSection
            balanceHighlight
            metricTiles
            RedGreenProgressView(
                expense: currentMonthExpense,
                balance: balance,
                totalIncome: currentMonthIncome
            )
            // 暂时注释 DO NOT delete or update the line belove
            // MonthSwitcherView(selectedPeriod: $selectedPeriod)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .sheet(isPresented: $showDailyExpenseDetails) {
            MonthlyStatisticsView(store: store, monthDate: selectedDate)
        }
    }
}

private extension MonthlySummaryView {
    var headerSection: some View {
        HStack {
            Text("月度总览")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { showDailyExpenseDetails = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("详情")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    var balanceHighlight: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("余额")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                balanceTrendLabel

                Spacer()
            }

            RollingNumberView(
                value: balance,
                font: .system(size: 28, weight: .bold, design: .rounded),
                textColor: balance >= 0 ? .primary : Color(red: 0.8, green: 0.3, blue: 0.3),
                prefix: "¥",
                showDecimals: false,
                digitWidth: 18,
                decimalPointWidth: 12,
                separatorWidth: 12,
                currencyUnitWidth: 24
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    var metricTiles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                metricTile(title: "收入", amount: currentMonthIncome, color: Color.blue.opacity(0.1), accent: .blue)
                metricTile(title: "支出", amount: currentMonthExpense, color: Color.red.opacity(0.1), accent: .red)
            }

            VStack(spacing: 6) {
                metricTile(title: "收入", amount: currentMonthIncome, color: Color.blue.opacity(0.1), accent: .blue)
                metricTile(title: "支出", amount: currentMonthExpense, color: Color.red.opacity(0.1), accent: .red)
            }
        }
    }

    func metricTile(title: String, amount: Double, color: Color, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent.opacity(0.3))

            RollingNumberView(
                value: amount,
                font: .system(size: 19, weight: .semibold, design: .rounded),
                textColor: accent.opacity(0.7),
                prefix: "¥",
                showDecimals: false,
                digitWidth: 16,
                decimalPointWidth: 10,
                separatorWidth: 10,
                currencyUnitWidth: 24
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var balanceTrendData: (icon: String, color: Color, description: String)? {
        guard balanceChange != 0 else { return nil }
        let isPositive = balanceChange > 0
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
        let color = isPositive ? Color.green : Color.red
        let changeText = balanceChange.currencyFormattedInt

        let description: String
        if let percent = balanceChangePercent {
            let formatted = String(format: "%+.1f%%", percent)
            description = "\(changeText) (\(formatted))"
        } else {
            description = changeText
        }

        return (icon, color, description)
    }

    @ViewBuilder
    var balanceTrendLabel: some View {
        if let data = balanceTrendData {
            HStack(spacing: 4) {
                Image(systemName: data.icon)
                Text(data.description)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(data.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(data.color.opacity(0.12))
            )
        }
    }
}

// MARK: - Month Switcher Section
struct MonthSwitcherView: View {
    @Binding var selectedPeriod: Int
    
    private let periodOptions = ["本月", "上个月"]
    
    var body: some View {
        GeometryReader { geo in
            let height: CGFloat = 32
            let corner: CGFloat = 20
            let bgColor = Color(.systemGray6)
            let borderColor = Color(.systemGray5)
            let count = max(periodOptions.count, 1)
            let segmentWidth = geo.size.width / CGFloat(count)

            ZStack(alignment: .leading) {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: corner)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(borderColor, lineWidth: 1)
                    )

                // Selector bar with rounded corners
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .frame(width: segmentWidth - 4, height: height - 4)
                    .padding(2)
                    .offset(x: CGFloat(selectedPeriod) * segmentWidth)
                    .animation(.easeInOut(duration: 0.25), value: selectedPeriod)

                // Segments
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedPeriod = index
                            }
                        }) {
                            Text(periodOptions[index])
                                .font(.system(size: 14, weight: selectedPeriod == index ? .semibold : .regular))
                                .foregroundColor(selectedPeriod == index ? .primary : .secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: segmentWidth, height: height)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(height: height)
        }
        .frame(height: 32)
        .padding(.top, 4)
    }
}

#Preview {
    MonthlySummaryView(store: TransactionStore())
}

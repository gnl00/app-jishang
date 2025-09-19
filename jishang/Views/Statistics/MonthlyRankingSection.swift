//
//  MonthlyRankingSection.swift
//  jishang
//
import SwiftUI

struct MonthlyRankingView: View {
    @ObservedObject var store: TransactionStore
    let timeRange: StatisticsView.TimeRange

    private var consideredMonths: [Date] {
        let calendar = Calendar.current
        let now = Date()
        let count: Int = {
            switch timeRange {
            case .allTime: return 12
            case .last12Months: return 12
            case .last6Months: return 6
            case .last3Months: return 3
            }
        }()
        return (0..<count).compactMap { i in
            calendar.date(byAdding: .month, value: -i, to: now)
        }.reversed()
    }

    private var monthlyPerformance: [(month: Date, income: Double, expense: Double, savings: Double, savingsRate: Double)] {
        return consideredMonths.map { month in
            let income = store.monthlyIncome(for: month)
            let expense = store.monthlyExpense(for: month)
            let savings = income - expense
            let savingsRate = income > 0 ? (savings / income) * 100 : 0
            return (month, income, expense, savings, savingsRate)
        }
    }

    private var bestSavingsMonth: (month: Date, amount: Double, rate: Double)? {
        let performance = monthlyPerformance.max { $0.savings < $1.savings }
        guard let best = performance else { return nil }
        return (best.month, best.savings, best.savingsRate)
    }

    private var highestExpenseMonth: (month: Date, amount: Double)? {
        let performance = monthlyPerformance.max { $0.expense < $1.expense }
        guard let highest = performance else { return nil }
        return (highest.month, highest.expense)
    }

    private var averageExpense: Double {
        let total = monthlyPerformance.reduce(0) { $0 + $1.expense }
        return monthlyPerformance.count > 0 ? total / Double(monthlyPerformance.count) : 0
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter
    }

    var body: some View {
        StatsSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("🧩 月度表现")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }

                VStack(spacing: 12) {
                    if let bestSavings = bestSavingsMonth {
                        SimplifiedRankingRow(
                            icon: "🏆",
                            title: "最佳储蓄月",
                            subtitle: "\(monthFormatter.string(from: bestSavings.month)) \(bestSavings.amount.currencyFormattedInt)"
                        )
                    }

                    if let highestExpense = highestExpenseMonth {
                        SimplifiedRankingRow(
                            icon: "📊",
                            title: "支出最高月",
                            subtitle: "\(monthFormatter.string(from: highestExpense.month)) \(highestExpense.amount.currencyFormattedInt)"
                        )
                    }

                    HStack {
                        Text("月度平均")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("支出\(averageExpense.currencyFormattedInt)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// 简化的排名行组件
private struct SimplifiedRankingRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}


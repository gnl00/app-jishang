//
//  FinancialHealthSection.swift
//  jishang
//
import SwiftUI

struct FinancialHealthScoreView: View {
    @ObservedObject var store: TransactionStore
    let timeRange: StatisticsView.TimeRange

    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return store.transactions.filter { t in
            switch timeRange {
            case .allTime:
                return true
            case .last12Months:
                return t.date >= (calendar.date(byAdding: .month, value: -12, to: now) ?? now)
            case .last6Months:
                return t.date >= (calendar.date(byAdding: .month, value: -6, to: now) ?? now)
            case .last3Months:
                return t.date >= (calendar.date(byAdding: .month, value: -3, to: now) ?? now)
            }
        }
    }

    private var savingsRate: Double {
        let income = filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        guard income > 0 else { return 0 }
        return ((income - expense) / income) * 100
    }

    private var recordingHabit: Double {
        let calendar = Calendar.current
        let now = Date()
        let last30Days = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let recentTransactions = filteredTransactions.filter { $0.date >= last30Days }
        let recordingDays = Set(recentTransactions.map { calendar.startOfDay(for: $0.date) }).count
        return Double(recordingDays) / 30.0 * 100
    }

    var body: some View {
        StatsSectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("💪 财务健康")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }

                VStack(spacing: 12) {
                    SimplifiedHealthRow(
                        title: "储蓄能力",
                        value: savingsRate,
                        unit: "%",
                        status: savingsRate >= 30 ? "优秀" : savingsRate >= 20 ? "良好" : "需改进"
                    )

                    SimplifiedHealthRow(
                        title: "记账频率",
                        value: recordingHabit,
                        unit: "%",
                        status: recordingHabit >= 80 ? "优秀" : recordingHabit >= 60 ? "良好" : "需改进"
                    )
                }
            }
        }
    }
}

struct SimplifiedHealthRow: View {
    let title: String
    let value: Double
    let unit: String
    let status: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(value.percentFormattedInt)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}


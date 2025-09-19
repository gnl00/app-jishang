//
//  CumulativeDataCardsView.swift
//  jishang
//
import SwiftUI

struct CumulativeDataCardsView: View {
    @ObservedObject var store: TransactionStore
    let timeFilter: StatisticsView.TimeRange

    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return store.transactions.filter { transaction in
            switch timeFilter {
            case .allTime:
                return true
            case .last12Months:
                return transaction.date >= (calendar.date(byAdding: .month, value: -12, to: now) ?? now)
            case .last6Months:
                return transaction.date >= (calendar.date(byAdding: .month, value: -6, to: now) ?? now)
            case .last3Months:
                return transaction.date >= (calendar.date(byAdding: .month, value: -3, to: now) ?? now)
            }
        }
    }

    private var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var netWorth: Double { totalIncome - totalExpense }

    private var totalMonths: Int {
        guard !filteredTransactions.isEmpty else { return 0 }
        let calendar = Calendar.current
        let dates = filteredTransactions.map { $0.date }
        let startDate = dates.min() ?? Date()
        let endDate = dates.max() ?? Date()
        return calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
    }

    private var totalTransactions: Int { filteredTransactions.count }

    private var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netWorth / totalIncome) * 100
    }

    var body: some View {
        StatsSectionCard {
            HStack(spacing: 0) {
                // 总收入
                VStack(spacing: 6) {
                    Text("总收入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(totalIncome.currencyFormattedInt)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text("\(totalMonths)个月")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color(.systemGray5)).frame(width: 1, height: 55)

                // 总支出
                VStack(spacing: 6) {
                    Text("总支出")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(totalExpense.currencyFormattedInt)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text("\(totalTransactions)笔")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color(.systemGray5)).frame(width: 1, height: 55)

                // 累计结余
                VStack(spacing: 6) {
                    Text("累计结余")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(netWorth.currencyFormattedInt)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(netWorth >= 0 ? .primary : Color.red)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text("储蓄率\(savingsRate.percentFormattedInt)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}


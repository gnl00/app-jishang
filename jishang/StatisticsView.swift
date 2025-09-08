//
//  StatisticsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall statistics
                    VStack(spacing: 16) {
                        StatisticCard(
                            title: "总收入",
                            amount: transactionStore.totalIncome,
                            color: .green
                        )
                        
                        StatisticCard(
                            title: "总支出",
                            amount: transactionStore.totalExpense,
                            color: .red
                        )
                        
                        StatisticCard(
                            title: "净资产",
                            amount: transactionStore.balance,
                            color: transactionStore.balance >= 0 ? .blue : .gray
                        )
                    }
                    .padding()
                    
                    // Category breakdown
                    CategoryBredownView(store: transactionStore)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatisticCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(amount.currencyFormatted)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CategoryBredownView: View {
    @ObservedObject var store: TransactionStore
    
    private var expenseByCategory: [Category: Double] {
        var breakdown: [Category: Double] = [:]
        
        for transaction in store.transactions where transaction.type == .expense {
            breakdown[transaction.category, default: 0] += transaction.amount
        }
        
        return breakdown
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("支出分类")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(expenseByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                    CategoryRowView(category: category, amount: amount, totalExpense: store.totalExpense)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryRowView: View {
    let category: Category
    let amount: Double
    let totalExpense: Double
    
    private var percentage: Double {
        guard totalExpense > 0 else { return 0 }
        return (amount / totalExpense) * 100
    }
    
    var body: some View {
        HStack {
            Text(category.icon)
                .font(.system(size: 18))
            
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount.currencyFormatted)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                
                Text("\(percentage, specifier: "%.1f")%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(TransactionStore())
}

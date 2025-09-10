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
                    
                    // Income pie chart
                    IncomePieChartView(store: transactionStore)
                    
                    // Expense pie chart
                    ExpensePieChartView(store: transactionStore)
                }
            }
            .background(Color(.systemGroupedBackground))
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


#Preview {
    StatisticsView()
        .environmentObject(TransactionStore())
}

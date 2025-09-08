//
//  TransactionListView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct TransactionListView: View {
    @ObservedObject var store: TransactionStore
    let selectedFilter: FilterType
    
    private var filteredTransactions: [Transaction] {
        return store.transactions
            .filter { selectedFilter.matches(transaction: $0) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        LazyVStack(spacing: 1) {
            ForEach(filteredTransactions) { transaction in
                TransactionRowView(transaction: transaction)
                    .onTapGesture {
                        // Handle transaction tap
                    }
            }
        }
        .padding(.horizontal)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.category.icon)
                        .font(.system(size: 18))
                    
                    Text(transaction.category.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .income ? "+" : "-")\(transaction.amount.currencyFormatted)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(transaction.type == .income ? .green : .red)
                
                Text(dateFormatter.string(from: transaction.date))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

#Preview {
    let store = TransactionStore()
    TransactionListView(store: store, selectedFilter: .all)
}

//
//  TransactionListView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI
import Pow

struct TransactionListView: View {
    @ObservedObject var store: TransactionStore
    let selectedFilter: FilterType
    
    @State private var editingTransaction: Transaction?
    @State private var showEditView = false
    @State private var deletingTransactionId: UUID?
    
    private var filteredTransactions: [Transaction] {
        return store.transactions
            .filter { selectedFilter.matches(transaction: $0) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        List(filteredTransactions) { transaction in
            TransactionRowView(transaction: transaction)
                .transition(.slide)
                .opacity(deletingTransactionId == transaction.id ? 0.3 : 1.0)
                .scaleEffect(deletingTransactionId == transaction.id ? 0.8 : 1.0)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("删除", role: .destructive) {
                        store.deleteTransaction(transaction)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button("编辑") {
                        editingTransaction = transaction
                    }
                    .tint(.blue)
                }
        }
        .listStyle(.plain)
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionView(
                store: store,
                editingTransaction: $editingTransaction,
                transactionType: transaction.type,
                initialTransaction: transaction
            )
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    @State private var isPressed = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY/MM/dd"
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
                        .transition(.slide.combined(with: .opacity))
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
        .padding(.vertical, 4)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            isPressed.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
}

#Preview {
    let store = TransactionStore()
    return TransactionListView(store: store, selectedFilter: .all)
}

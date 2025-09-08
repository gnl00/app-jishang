//
//  HomeView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @State private var selectedFilter: FilterType = .all
    @State private var presentedTransactionType: TransactionType?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top action buttons (add expense/income)
                VStack(spacing: 16) {
                    SummaryCardsView(
                        onExpenseAction: {
                            presentedTransactionType = .expense
                        },
                        onIncomeAction: {
                            presentedTransactionType = .income
                        }
                    )
                    
                    // Monthly statistics
                    MonthlyStatisticsView(store: transactionStore)
                }
                .padding(.top)
                
                // Category filter tab bar
                CategoryFilterView(store: transactionStore, selectedFilter: $selectedFilter)
                    .padding(.vertical, 8)
                
                // Transaction list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        TransactionListView(
                            store: transactionStore,
                            selectedFilter: selectedFilter
                        )
                    }
                    .padding(.top, 8)
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("记账本")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $presentedTransactionType) { type in
                AddTransactionView(
                    store: transactionStore,
                    isPresented: Binding(
                        get: { presentedTransactionType != nil },
                        set: { if !$0 { presentedTransactionType = nil } }
                    ),
                    transactionType: type
                )
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(TransactionStore())
}
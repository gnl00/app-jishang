//
//  HomeView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @State private var selectedFilter: FilterCategory = .all
    @State private var showAddTransaction = false
    @State private var transactionType: TransactionType = .expense
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top action buttons (add expense/income)
                VStack(spacing: 16) {
                    SummaryCardsView(
                        onExpenseAction: {
                            transactionType = .expense
                            showAddTransaction = true
                        },
                        onIncomeAction: {
                            transactionType = .income
                            showAddTransaction = true
                        }
                    )
                    
                    // Monthly statistics
                    MonthlyStatisticsView(store: transactionStore)
                }
                .padding(.top)
                
                // Category filter tab bar
                CategoryFilterView(selectedFilter: $selectedFilter)
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
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(
                    store: transactionStore,
                    isPresented: $showAddTransaction,
                    transactionType: transactionType
                )
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(TransactionStore())
}
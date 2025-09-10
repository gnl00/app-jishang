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
    @State private var showVoiceInput = false
    @State private var voiceInputType: TransactionType = .expense
    
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
                        },
                        onVoiceExpenseAction: {
                            voiceInputType = .expense
                            showVoiceInput = true
                        },
                        onVoiceIncomeAction: {
                            voiceInputType = .income
                            showVoiceInput = true
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
                TransactionListView(
                    store: transactionStore,
                    selectedFilter: selectedFilter
                )
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
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
            .sheet(isPresented: $showVoiceInput) {
                VoiceInputView(
                    isPresented: $showVoiceInput,
                    transactionType: voiceInputType
                ) { voiceText in
                    handleVoiceResult(voiceText)
                }
            }
        }
    }
    
    private func handleVoiceResult(_ voiceText: String) {
        let parser = VoiceTransactionParser()
        
        guard let parsedTransaction = parser.parseVoiceText(voiceText, expectedType: voiceInputType) else {
            print("无法解析语音内容: \(voiceText)")
            return
        }
        
        // 查找匹配的类别
        var selectedCategory: Category?
        if let categoryName = parsedTransaction.category {
            selectedCategory = transactionStore.allCategories.first { category in
                category.name == categoryName && 
                (category.defaultType == parsedTransaction.type || category.isCustom)
            }
        }
        
        // 如果没有找到匹配的类别，使用默认类别
        if selectedCategory == nil {
            selectedCategory = transactionStore.allCategories.first { category in
                category.defaultType == parsedTransaction.type && !category.isCustom
            }
        }
        
        // 创建交易记录
        if let category = selectedCategory {
            let transaction = Transaction(
                amount: parsedTransaction.amount,
                category: category,
                type: parsedTransaction.type,
                date: Date(),
                note: parsedTransaction.description
            )
            
            transactionStore.addTransaction(transaction)
            print("语音记账成功: \(parsedTransaction.description) - ¥\(parsedTransaction.amount)")
        } else {
            print("无法找到合适的类别")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(TransactionStore())
}

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
    
    // Collapsing MonthlySummary
    @State private var summaryHeight: CGFloat = 0
    @State private var summaryMinY: CGFloat = 0
    
    // Inline list edit/delete support
    @State private var editingTransaction: Transaction?
    @State private var deletingTransactionId: UUID?
    
    private var filteredTransactions: [Transaction] {
        return transactionStore.transactions
            .filter { selectedFilter.matches(transaction: $0) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top action buttons (add expense/income)
                VStack(spacing: 16) {
                    SummaryCardsView(
                        store: transactionStore,
                        onExpenseAction: { presentedTransactionType = .expense },
                        onIncomeAction: { presentedTransactionType = .income },
                        onVoiceExpenseAction: {
                            voiceInputType = .expense
                            showVoiceInput = true
                        },
                        onVoiceIncomeAction: {
                            voiceInputType = .income
                            showVoiceInput = true
                        }
                    )
                }
                .padding(.top)
                
                // Scrollable content: MonthlySummary (collapsible) + CategoryFilter (sticky) + Transactions
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                        // Collapsible Monthly Summary
                        monthlySummaryCollapsible
                            .padding(.top, 8)
                        
                        // Sticky Category Filter + Transaction rows
                        Section {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredTransactions) { transaction in
                                    transactionRow(for: transaction)
                                }
                                .animation(.default, value: filteredTransactions.count)
                                .padding(.bottom, 20)
                            }
                            .padding(.horizontal, 8)
                        } header: {
                            CategoryFilterView(store: transactionStore, selectedFilter: $selectedFilter)
                                .padding(.vertical, 4)
                                .background(
                                    // Solid background when pinned
                                    Color(.systemGroupedBackground)
                                        .ignoresSafeArea()
                                )
                                .overlay(alignment: .bottom) {
                                    Divider().opacity(0.6)
                                }
                        }
                    }
                }
                .coordinateSpace(name: "homeScroll")
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            // Sheet: add income/expense
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
            // Sheet: voice input
            .sheet(isPresented: $showVoiceInput) {
                VoiceInputView(
                    isPresented: $showVoiceInput,
                    transactionType: voiceInputType
                ) { voiceText in
                    handleVoiceResult(voiceText)
                }
            }
            // Sheet: edit transaction
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(
                    store: transactionStore,
                    editingTransaction: $editingTransaction,
                    transactionType: transaction.type,
                    initialTransaction: transaction
                )
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

// MARK: - Collapsible Monthly Summary
extension HomeView {
    private var monthlySummaryCollapsible: some View {
        let effectiveHeight = max(0, summaryHeight - max(0, -summaryMinY))
        let progress = summaryHeight > 0 ? 1 - (effectiveHeight / summaryHeight) : 0
        return MonthlySummaryView(store: transactionStore)
            // Measure intrinsic height BEFORE frame applied
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SummaryHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            // Track vertical offset in scroll space BEFORE frame applied
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SummaryMinYPreferenceKey.self, value: proxy.frame(in: .named("homeScroll")).minY)
                }
            )
            // Visual refinement when collapsing
            .opacity(max(0.0, 1.0 - progress * 1.2))
            .scaleEffect(x: 1.0, y: max(0.85, 1.0 - progress * 0.1), anchor: .top)
            .frame(height: summaryHeight == 0 ? nil : effectiveHeight)
            .clipped(antialiased: true)
            .onPreferenceChange(SummaryHeightPreferenceKey.self) { self.summaryHeight = $0 }
            .onPreferenceChange(SummaryMinYPreferenceKey.self) { self.summaryMinY = $0 }
    }
}

private struct SummaryHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Use the first non-zero reading
        let new = nextValue()
        if value == 0 { value = new }
    }
}

private struct SummaryMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Transaction Row Wrapper
extension HomeView {
    @ViewBuilder
    private func transactionRow(for transaction: Transaction) -> some View {
        TransactionRowView(transaction: transaction)
            .listRowInsets(EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            .opacity(deletingTransactionId == transaction.id ? 0.3 : 1.0)
            .scaleEffect(deletingTransactionId == transaction.id ? 0.8 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deletingTransactionId)
            .contextMenu {
                Button("编辑", systemImage: "pencil") {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    editingTransaction = transaction
                }
                Button("删除", systemImage: "trash", role: .destructive) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        deletingTransactionId = transaction.id
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        transactionStore.deleteTransaction(transaction)
                        deletingTransactionId = nil
                    }
                }
            }
    }
}

#Preview {
    HomeView()
        .environmentObject(TransactionStore())
}

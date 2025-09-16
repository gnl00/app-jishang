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

    // MonthlySummaryView 折叠状态管理
    @State private var isCollapsed: Bool = false
    
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
                .padding(.bottom, 6)

                if !isCollapsed {
                    MonthlySummaryView(store: transactionStore)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .transition(
                            .asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            )
                        )
                }

                if isCollapsed {
                    CollapsedSummaryView {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isCollapsed = false
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                CategoryFilterView(
                    store: transactionStore,
                    selectedFilter: $selectedFilter
                )
                .background(Color(.systemGroupedBackground))
                .zIndex(1)

                TransactionListView(
                    store: transactionStore,
                    selectedFilter: selectedFilter,
                    isCollapsed: $isCollapsed
                )
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

// MARK: - Collapsed Summary View
struct CollapsedSummaryView: View {
    let onExpandAction: () -> Void

    init(onExpandAction: @escaping () -> Void) {
        self.onExpandAction = onExpandAction
    }

    var body: some View {
        VStack(spacing: 0) {
            // 月度总览展开按钮
            Button(action: {
                // Haptic反馈
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()

                // 执行展开动作
                onExpandAction()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.leading)

                    Text("月度总览")
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Text("（点击展开）")
                        .font(.system(size: 13, weight: .medium))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.trailing)
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray6), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(TransactionStore())
}

// MARK: - Helpers
private extension View {
    // Conditionally apply .scrollBounceBehavior(.basedOnSize) when available
    @ViewBuilder
    func applyBasedOnSizeBounce() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

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
    @State private var isCollapsed: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var layoutChangeTime: Date = Date() // 记录布局变化时间
    
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
                .padding(.bottom, 6)
                
                // Scrollable content: MonthlySummary (collapsible) + CategoryFilter (sticky) + Transactions
                GeometryReader { outer in
                    let viewportHeight = outer.size.height
                    Group {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                                    // Scroll tracking element at the top
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 1)
                                        .id("scrollTop")
                                        .background(
                                            GeometryReader { proxy in
                                                let offset = proxy.frame(in: .global).minY
                                                let _ = print("GeometryReader global offset: \(offset)")

                                                // 直接调用处理函数而不是使用 PreferenceKey
                                                DispatchQueue.main.async {
                                                    handleScrollChange(offset: offset, viewportHeight: viewportHeight)
                                                }

                                                return Color.clear
                                            }
                                        )

                                    // Collapsible Monthly Summary
                                    if !isCollapsed {
                                        monthlySummarySimple
                                            .padding(.top, 8)
                                    }

                                // Sticky Category Filter + Transaction rows
                                Section {
                                    LazyVStack(spacing: 4) {
                                        ForEach(filteredTransactions) { transaction in
                                            transactionRow(for: transaction)
                                        }
                                        .animation(.default, value: filteredTransactions.count)
                                        .padding(.bottom, 1)
                                    }
                                    .padding(.horizontal, 8)
                                } header: {
                                    VStack(spacing: 0) {
                                        // 折叠后的月度总览组件 - 包含占位元素和展开按钮
                                        let _ = print("isCollapsed: \(isCollapsed)")
                                        if isCollapsed {
                                            CollapsedSummaryView {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    isCollapsed = false
                                                }
                                            }
                                            .transition(.asymmetric(
                                                insertion: .movingParts.boing,
                                                removal: .move(edge: .top).combined(with: .opacity)
                                            ))
                                            .zIndex(1)
                                        }

                                        CategoryFilterView(store: transactionStore, selectedFilter: $selectedFilter)
                                            .padding(.bottom, 4)
                                            .background(
                                                // Solid background when pinned
                                                Color(.systemGroupedBackground)
                                                    .ignoresSafeArea()
                                            )
                                            .overlay(alignment: .bottom) {
                                                Divider().opacity(0.6)
                                            }
                                    }
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCollapsed)
                                }
                                }
                                // Ensure enough content height to avoid rubber-banding when list is short,
                                // and keep content aligned to top instead of vertically centering.
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: viewportHeight, alignment: .top)
                            }
                        }
                        .coordinateSpace(name: "homeScroll")
                        // Avoid bouncing when content is not taller than the viewport (iOS 16+)
                        .applyBasedOnSizeBounce()
                        .background(Color(.systemGroupedBackground))
                    }
                }
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

// MARK: - Monthly Summary
extension HomeView {
    private var monthlySummarySimple: some View {
        MonthlySummaryView(store: transactionStore)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
    }

    private func handleScrollChange(offset: CGFloat, viewportHeight: CGFloat) {
        let _ = print("lastScrollOffset:\(lastScrollOffset) scrollOffset:\(scrollOffset) offset:\(offset)")

        // 首次调用时记录初始偏移量
        if lastScrollOffset == 0 && scrollOffset == 0 {
            lastScrollOffset = offset
            scrollOffset = offset
            return
        }

        let scrollDelta = offset - lastScrollOffset
        let now = Date()

        // 检测异常的位置跳跃（布局变化引起），忽略这些变化
        if abs(scrollDelta) > 100 {
            let _ = print("位置跳跃检测: \(scrollDelta)，重置基准")
            layoutChangeTime = now // 记录布局变化时间
            lastScrollOffset = offset
            scrollOffset = offset
            return
        }

        // 布局变化后短时间内的滚动检测需要更宽松的条件
        let timeSinceLayoutChange = now.timeIntervalSince(layoutChangeTime)
        let isRecentLayoutChange = timeSinceLayoutChange < 0.3

        lastScrollOffset = offset
        scrollOffset = offset

        // 使用全局坐标，较小的 offset 表示向上滚动了更多
        let isScrollingUp = scrollDelta < -3
        let isScrollingDown = scrollDelta > 3 // 新增：检测向下滚动

        // 动态调整折叠阈值：最近有布局变化时使用更宽松的条件
        let collapseThreshold: CGFloat = isRecentLayoutChange ? 150 : 80
        let hasScrolledEnough = offset < collapseThreshold

        let _ = print("scrollDelta:\(scrollDelta) isScrollingUp:\(isScrollingUp) isScrollingDown:\(isScrollingDown) hasScrolledEnough:\(hasScrolledEnough) isCollapsed:\(isCollapsed) timeSince:\(timeSinceLayoutChange)")

        // 折叠逻辑
        if isScrollingUp && hasScrolledEnough && !isCollapsed {
            layoutChangeTime = now // 状态改变时更新时间
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isCollapsed = true
            }
        }

        // 展开逻辑：优化为更响应的条件
        // 1. 用户主动向下滚动到顶部附近 - 立即响应
        // 2. 或者布局稳定后的静态位置检查
        let shouldExpandForUserPull = isScrollingDown && offset > 250 && isCollapsed
        let shouldExpandForPosition = offset > 200 && isCollapsed && !isRecentLayoutChange

        if shouldExpandForUserPull || shouldExpandForPosition {
            let _ = print("展开触发 - 用户下拉:\(shouldExpandForUserPull) 位置检查:\(shouldExpandForPosition)")
            layoutChangeTime = now // 状态改变时更新时间
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isCollapsed = false
            }
        }
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

// MARK: - Collapsed Summary View
struct CollapsedSummaryView: View {
    let onExpandAction: () -> Void

    init(onExpandAction: @escaping () -> Void) {
        self.onExpandAction = onExpandAction
    }

    var body: some View {
        VStack(spacing: 0) {
            // 占位元素 - 灰色分隔条
            HStack {
                Spacer()
            }
            .padding(.vertical, 2)
            .background(Color(.systemGray6))

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

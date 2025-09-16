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
    @Binding var selectedFilter: FilterType
    @Binding var isCollapsed: Bool

    @State private var editingTransaction: Transaction?
    @State private var showEditView = false
    @State private var deletingTransactionId: UUID?
    @State private var lastLoggedBucket: Int = Int.min

    // 滚动方向检测
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollDirection: ScrollDirection = .none
    @State private var isStateChanging: Bool = false  // 状态变化保护期
    @State private var lastStateChangeTime: Date = Date()
    @State private var isFilterChanging: Bool = false  // filter变化保护期
    @State private var lastFilterChangeTime: Date = Date()
    @State private var isScrollingToTop: Bool = false  // scrollToTop保护期
    @State private var lastScrollToTopTime: Date = Date()

    enum ScrollDirection {
        case up      // 上滑
        case down    // 下拉
        case none    // 无滚动
    }
    

    // 移除 filteredTransactions 计算属性，过滤逻辑下沉到子组件

    var body: some View {
        let _ = print("[DEBUG] TransactionListView body render - isCollapsed: \(isCollapsed)")
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                    // 添加滚动锚点
                    Color.clear
                        .frame(height: 0)
                        .id("top")

                    Section {
                        // Transactions - 使用独立组件处理过滤和渲染
                        FilteredTransactionsList(
                            transactions: store.transactions,
                            selectedFilter: selectedFilter,
                            onEditTransaction: { transaction in
                                editingTransaction = transaction
                            },
                            onDeleteTransaction: { transaction in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    deletingTransactionId = transaction.id
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    store.deleteTransaction(transaction)
                                    deletingTransactionId = nil
                                }
                            },
                            deletingTransactionId: deletingTransactionId
                        )
                    } header: {
                        CategoryFilterView(
                            store: store,
                            selectedFilter: $selectedFilter
                        )
                        .padding(.top, 8)      // 顶部内边距，避免与状态栏重叠
                        .padding(.bottom, 12)  // 增加底部内边距，为下方内容留出空间
                        .background(
                            Color(.systemGroupedBackground)
                                .ignoresSafeArea()
                        )
                        .overlay(alignment: .bottom) {
                            Divider().opacity(0.6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color(.systemGroupedBackground))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // 使用 contentOffset.y 作为滚动偏移值
                return geometry.contentOffset.y
            } action: { oldValue, newValue in
                let currentTime = Date()

                // 在各种保护期内忽略滚动检测
                if isStateChanging || currentTime.timeIntervalSince(lastStateChangeTime) < 0.5 {
                    print("[SCROLL-DEBUG] Ignoring scroll during state change protection period")
                    return
                }

                if isFilterChanging || currentTime.timeIntervalSince(lastFilterChangeTime) < 0.8 {
                    print("[SCROLL-DEBUG] Ignoring scroll during filter change protection period")
                    return
                }

                if isScrollingToTop || currentTime.timeIntervalSince(lastScrollToTopTime) < 0.6 {
                    print("[SCROLL-DEBUG] Ignoring scroll during scrollToTop protection period")
                    return
                }

                // 计算滚动方向
                let offsetDifference = newValue - oldValue
                let threshold: CGFloat = 10.0 // 增加阈值，减少敏感度

                // 更新滚动方向
                if abs(offsetDifference) > threshold {
                    let newDirection: ScrollDirection = offsetDifference > 0 ? .up : .down

                    if newDirection != scrollDirection {
                        scrollDirection = newDirection

                        // 根据滚动方向控制 isCollapsed 状态，但只在状态真正需要改变时
                        let shouldChangeState = (scrollDirection == .up && !isCollapsed) ||
                                               (scrollDirection == .down && isCollapsed)

                        if shouldChangeState {
                            // 设置状态变化保护期
                            isStateChanging = true
                            lastStateChangeTime = currentTime

                            switch scrollDirection {
                            case .up:
                                // 上滑时折叠
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isCollapsed = true
                                }
                                print("[SCROLL-DIRECTION] Up scroll detected -> Collapsing MonthlySummaryView")
                            case .down:
                                // 下拉时展开
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isCollapsed = false
                                }
                                print("[SCROLL-DIRECTION] Down scroll detected -> Expanding MonthlySummaryView")
                            case .none:
                                break
                            }

                            // 延迟重置保护期
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isStateChanging = false
                            }
                        }
                    }
                }

                // 简化的滚动偏移日志记录
                let bucket = Int((newValue / 20).rounded())
                if bucket != lastLoggedBucket {
                    lastLoggedBucket = bucket
                    print("[SCROLL-DEBUG] scrollOffset:\(String(format: "%.1f", newValue)) direction:\(scrollDirection) isCollapsed:\(isCollapsed)")
                }
            }
            .onChange(of: selectedFilter) { oldFilter, newFilter in
                print("[FILTER-CHANGE] Filter changed from '\(oldFilter.displayName)' to '\(newFilter.displayName)'")

                let currentTime = Date()

                // 设置各种保护期
                isFilterChanging = true
                lastFilterChangeTime = currentTime
                isScrollingToTop = true
                lastScrollToTopTime = currentTime

                // ScrollToTop when filter changes
                withAnimation(.easeInOut(duration: 0.4)) {
                    scrollProxy.scrollTo("top", anchor: .top)
                }

                // 延迟重置保护期，给内容变化和动画足够的时间
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isFilterChanging = false
                    print("[FILTER-CHANGE] Filter change protection period ended")
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isScrollingToTop = false
                    print("[SCROLL-TO-TOP] ScrollToTop protection period ended")
                }
            }
        }
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
        formatter.dateFormat = "MM/dd"
        return formatter
    }
    
    // 卡片背景颜色
    private var cardBackgroundColor: Color {
        if transaction.type == .income {
            return Color.green.opacity(0.05)
        } else {
            return Color.red.opacity(0.05)
        }
    }
    
    // 卡片边框颜色
    private var cardBorderColor: Color {
        if transaction.type == .income {
            return Color.green.opacity(0.2)
        } else {
            return Color.red.opacity(0.2)
        }
    }
    
    // 金额颜色
    private var amountColor: Color {
        transaction.type == .income ? Color.green : Color.red
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：图标和分类信息
            HStack(spacing: 12) {
                // 图标容器
                ZStack {
                    Circle()
                        .fill(cardBorderColor.opacity(0.3))
                        .frame(width: 38, height: 38)
                    
                    Text(transaction.category.icon)
                        .font(.system(size: 20))
                }
                
                // 分类和备注信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.category.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        // 占位空间，保持布局一致性
                        Text(" ")
                            .font(.system(size: 13))
                            .opacity(0)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // 右侧：金额和日期
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .income ? "+" : "-")\(transaction.amount.currencyFormatted)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: transaction.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                // 主背景：白色卡片
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                
                // 左上角三角形背景色 (较淡)
                VStack {
                    HStack {
                        TriangleCornerTopLeft(color: cardBorderColor.opacity(0.6))
                            .frame(width: 32, height: 32)
                        Spacer()
                    }
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 右下角三角形背景色 (较深)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        TriangleCornerBottomRight(color: cardBorderColor.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .shadow(
            color: Color.black.opacity(isPressed ? 0.1 : 0.05),
            radius: isPressed ? 8 : 4,
            x: 0,
            y: isPressed ? 4 : 2
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Filtered Transactions List Component
struct FilteredTransactionsList: View {
    let transactions: [Transaction]
    let selectedFilter: FilterType
    let onEditTransaction: (Transaction) -> Void
    let onDeleteTransaction: (Transaction) -> Void
    let deletingTransactionId: UUID?

    // 过滤逻辑只在这个组件内部，不影响父组件
    private var filteredTransactions: [Transaction] {
        let filtered = transactions
            .filter { selectedFilter.matches(transaction: $0) }
            .sorted { $0.date > $1.date }

        print("[FILTER-LIST-DEBUG] Filtered \(transactions.count) -> \(filtered.count) transactions for filter: \(selectedFilter)")
        return filtered
    }

    var body: some View {
        let _ = print("[FILTER-LIST-DEBUG] FilteredTransactionsList body render for filter: \(selectedFilter)")

        LazyVStack(spacing: 4) {
            ForEach(filteredTransactions) { transaction in
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
                            onEditTransaction(transaction)
                        }

                        Button("删除", systemImage: "trash", role: .destructive) {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            onDeleteTransaction(transaction)
                        }
                    }
            }

            // 添加一个最小高度的占位符，确保内容变化时高度相对稳定
            if filteredTransactions.count < 3 {
                ForEach(0..<(3 - filteredTransactions.count), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 80) // 大约一个交易行的高度
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)  // 添加顶部间距，避开固定的 CategoryFilterView
        .padding(.bottom, 1)
        .frame(minHeight: 240) // 确保至少有 3 行交易的高度
    }
}

// MARK: - Triangle Corner Shapes

/// 左上角三角形
struct TriangleCornerTopLeft: View {
    let color: Color
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))           // 左上角
            path.addLine(to: CGPoint(x: size.width, y: 0)) // 右上角
            path.addLine(to: CGPoint(x: 0, y: size.height)) // 左下角
            path.closeSubpath()
            
            context.fill(path, with: .color(color))
        }
    }
}

/// 右下角三角形
struct TriangleCornerBottomRight: View {
    let color: Color
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width, y: 0))    // 右上角
            path.addLine(to: CGPoint(x: size.width, y: size.height)) // 右下角
            path.addLine(to: CGPoint(x: 0, y: size.height)) // 左下角
            path.closeSubpath()
            
            context.fill(path, with: .color(color))
        }
    }
}

// MARK: - Utilities
// ScrollOffsetKey 已移除，使用 iOS 18 的 onScrollGeometryChange 替代


#if canImport(SwiftUI)
private extension View {
    @ViewBuilder
    func applyScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    // iOS 17+ smooth scroll-based fade+scale for appearing/disappearing content
    @ViewBuilder
    func applyScrollFadeScale() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTransition { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1.0 : 0.98)
                    .opacity(phase.isIdentity ? 1.0 : 0.0)
            }
        } else {
            self
        }
    }
}
#endif

#Preview {
    let store = TransactionStore()
    return TransactionListView(
        store: store,
        selectedFilter: .constant(.all),
        isCollapsed: .constant(false)
    )
}

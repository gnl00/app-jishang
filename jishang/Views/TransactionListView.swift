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

    @State private var editingTransaction: Transaction?
    @State private var showEditView = false
    @State private var deletingTransactionId: UUID?
    // Internal collapse state
    @State private var isCollapsed: Bool = false
    @State private var lastLoggedBucket: Int = Int.min

    // CategoryFilterView sticky state tracking
    @State private var categoryFilterSticky: Bool = false
    

    private var filteredTransactions: [Transaction] {
        return store.transactions
            .filter { selectedFilter.matches(transaction: $0) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let _ = print("[DEBUG] TransactionListView body render - isCollapsed: \(isCollapsed)")
        ScrollViewReader { _ in
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    // Top offset reporter for continuous scroll logging (debug)
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: proxy.frame(in: .named("txScroll")).minY
                                )
                            }
                        )
                    // Expanded: show monthly summary at top
                    if !isCollapsed {
                        MonthlySummaryView(store: store)
                            .padding(.top, 8)
                            .applyScrollFadeScale()
                            .transition(
                                .asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                )
                            )
                            .onAppear {
                                print("[DEBUG] MonthlySummaryView appeared - isCollapsed: \(isCollapsed)")
                            }
                    }

                    // CategoryFilter 哨兵 - 用于检测 CategoryFilterView 的位置
                    Color.clear
                        .frame(height: 1)
                        .background(
                            GeometryReader { proxy in
                                let frame = proxy.frame(in: .named("txScroll"))
                                let isSticky = frame.minY <= 0
                                Color.clear
                                    .preference(
                                        key: CategoryFilterStickyPreferenceKey.self,
                                        value: ["categoryFilter": isSticky]
                                    )
                                    .onChange(of: frame.minY) { minY in
                                        print("[SENTINEL-DEBUG] Sentinel minY: \(String(format: "%.2f", minY)), isSticky: \(minY <= 0)")
                                    }
                            }
                        )

                    Section {
                        // Transactions
                        LazyVStack(spacing: 4) {
                            ForEach(filteredTransactions) { transaction in
                                transactionRow(for: transaction)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 1)
                    } header: {
                        VStack(spacing: 0) {
                            if isCollapsed {
                                CollapsedSummaryView {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isCollapsed = false
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .onAppear {
                                    print("[DEBUG] CollapsedSummaryView appeared - isCollapsed: \(isCollapsed)")
                                }
                            }

                            CategoryFilterView(
                                store: store,
                                selectedFilter: $selectedFilter
                            )
                            .padding(.bottom, 4)
                        }
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
            .coordinateSpace(name: "txScroll")
            .background(Color(.systemGroupedBackground))
            .onPreferenceChange(CategoryFilterStickyPreferenceKey.self) { preferences in
                let _ = print("onPreferenceChange on pin state change")
                if let isSticky = preferences["categoryFilter"] {
                    if categoryFilterSticky != isSticky {
                        categoryFilterSticky = isSticky
                        print("[STICKY-DEBUG] CategoryFilterView pinned state changed: \(isSticky ? "PINNED" : "UNPINNED")")

                        // 这里可以添加对 pinned 状态变化的响应逻辑
                        onCategoryFilterViewSticky(isSticky)
                    }
                }
            }
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                // 简化的滚动偏移日志记录
                let bucket = Int((offset / 20).rounded())
                if bucket != lastLoggedBucket {
                    lastLoggedBucket = bucket
                    print("[SCROLL-DEBUG] scrollOffset:\(String(format: "%.1f", offset)) isCollapsed:\(isCollapsed)")
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
                    // 轻触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    editingTransaction = transaction
                }

                Button("删除", systemImage: "trash", role: .destructive) {
                    // 重触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        deletingTransactionId = transaction.id
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        store.deleteTransaction(transaction)
                        deletingTransactionId = nil
                    }
                }
            }
    }

    // MARK: - CategoryFilterView Sticky Handler
    private func onCategoryFilterViewSticky(_ isSticky: Bool) {
        print("[STICKY-DEBUG] onCategoryFilterViewSticky called with isSticky: \(isSticky)")

        // 在这里可以根据 CategoryFilterView 的 pinned 状态来控制 MonthlySummaryView 的显示/隐藏
        // 例如：当 CategoryFilterView 被 pinned 时，折叠 MonthlySummaryView
        if isSticky && !isCollapsed {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isCollapsed = true
            }
            print("[STICKY-DEBUG] CategoryFilterView pinned -> Collapsing MonthlySummaryView")
        } else if !isSticky && isCollapsed {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isCollapsed = false
            }
            print("[STICKY-DEBUG] CategoryFilterView unpinned -> Expanding MonthlySummaryView")
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
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 自定义 PreferenceKey 用于传输 CategoryFilterView 的 Sticky 状态
private struct CategoryFilterStickyPreferenceKey: PreferenceKey {
    typealias Value = [String: Bool]

    static var defaultValue: Value = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { _, new in new }
    }
}

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
        selectedFilter: .constant(.all)
    )
}

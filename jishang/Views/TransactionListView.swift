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
            transactionRow(for: transaction)
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
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

#Preview {
    let store = TransactionStore()
    return TransactionListView(store: store, selectedFilter: .all)
}

//
//  SummaryCardView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI
import Pow

struct ActionButtonView: View {
    let title: String
    let icon: String
    let borderColor: Color
    let iconColor: Color
    let textColor: Color
    let action: () -> Void
    let longPressAction: (() -> Void)?
    
    init(title: String, icon: String, borderColor: Color, iconColor: Color, textColor: Color, action: @escaping () -> Void, longPressAction: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.borderColor = borderColor
        self.iconColor = iconColor
        self.textColor = textColor
        self.action = action
        self.longPressAction = longPressAction
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(iconColor.opacity(0.5))
                        .changeEffect(.wiggle, value: isPressed)
                        .changeEffect(.glow, value: isPressed)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
                .padding()
            )
            .frame(height: 100)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .changeEffect(.wiggle, value: isPressed)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                // 短按震动反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity, perform: {
                // 长按震动反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                longPressAction?()
            }, onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            })
    }
    
    @State private var isPressed = false
}

struct SummaryCardsView: View {
    @ObservedObject var store: TransactionStore
    let onExpenseAction: () -> Void
    let onIncomeAction: () -> Void
    let onVoiceExpenseAction: (() -> Void)?
    let onVoiceIncomeAction: (() -> Void)?

    init(store: TransactionStore,
         onExpenseAction: @escaping () -> Void,
         onIncomeAction: @escaping () -> Void,
         onVoiceExpenseAction: (() -> Void)? = nil,
         onVoiceIncomeAction: (() -> Void)? = nil) {
        self.store = store
        self.onExpenseAction = onExpenseAction
        self.onIncomeAction = onIncomeAction
        self.onVoiceExpenseAction = onVoiceExpenseAction
        self.onVoiceIncomeAction = onVoiceIncomeAction
    }

    // 计算今日交易数量
    private var todayTransactionCount: Int {
        let calendar = Calendar.current
        let today = Date()
        return store.transactions.filter { transaction in
            calendar.isDate(transaction.date, inSameDayAs: today)
        }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with stats
            HStack {
                Text("💰 记账中心")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("今日第 \(todayTransactionCount) 笔")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            // Action Cards
            HStack(spacing: 12) {
                // Income Card - 收入：箭头向下（钱流入账户）
                ImprovedActionCard(
                    title: "记收入",
                    icon: "arrow.down.circle.fill",
                    gradientColors: [
                        Color.green.opacity(0.6),
                        Color.green.opacity(0.4)
                    ],
                    primaryColor: .green,
                    hasVoiceFeature: onVoiceIncomeAction != nil,
                    action: onIncomeAction,
                    longPressAction: onVoiceIncomeAction
                )
                
                // Expense Card - 支出：箭头向上（钱花出去）
                ImprovedActionCard(
                    title: "记支出", 
                    icon: "arrow.up.circle.fill",
                    gradientColors: [
                        Color.red.opacity(0.6),
                        Color.red.opacity(0.4)
                    ],
                    primaryColor: .red,
                    hasVoiceFeature: onVoiceExpenseAction != nil,
                    action: onExpenseAction,
                    longPressAction: onVoiceExpenseAction
                )
            }
        }
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Improved Action Card
struct ImprovedActionCard: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    let primaryColor: Color
    let hasVoiceFeature: Bool
    let action: () -> Void
    let longPressAction: (() -> Void)?
    
    @State private var isPressed = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 12) {
                    // Main Icon
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .changeEffect(.wiggle, value: isPressed)
                        .changeEffect(.glow, value: isPressed)
                    
                    // Title
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Voice Feature Indicator
                    if hasVoiceFeature {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Text("长按语音")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
                .padding()
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .frame(height: 120)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: primaryColor.opacity(0.3),
                radius: isPressed ? 8 : 4,
                x: 0,
                y: isPressed ? 4 : 2
            )
            .animation(.easeInOut(duration: 0.15), value: isPressed)
            .contentShape(Rectangle())
            .onTapGesture {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                action()
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity, perform: {
                if hasVoiceFeature {
                    // Stronger haptic feedback for long press
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                    longPressAction?()
                }
            }, onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPressed = pressing
                }
            })
    }
}

#Preview {
    SummaryCardsView(
        store: TransactionStore(),
        onExpenseAction: { print("Add expense") },
        onIncomeAction: { print("Add income") },
        onVoiceExpenseAction: { print("Voice expense") },
        onVoiceIncomeAction: { print("Voice income") }
    )
}

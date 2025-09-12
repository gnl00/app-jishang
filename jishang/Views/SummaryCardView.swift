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
    let onExpenseAction: () -> Void
    let onIncomeAction: () -> Void
    let onVoiceExpenseAction: (() -> Void)?
    let onVoiceIncomeAction: (() -> Void)?
    
    @State private var todayTransactionCount: Int = 3 // TODO: 从实际数据获取
    
    init(onExpenseAction: @escaping () -> Void, 
         onIncomeAction: @escaping () -> Void,
         onVoiceExpenseAction: (() -> Void)? = nil,
         onVoiceIncomeAction: (() -> Void)? = nil) {
        self.onExpenseAction = onExpenseAction
        self.onIncomeAction = onIncomeAction
        self.onVoiceExpenseAction = onVoiceExpenseAction
        self.onVoiceIncomeAction = onVoiceIncomeAction
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
            
            // Circular center layout
            CircularActionLayout(
                onIncomeAction: onIncomeAction,
                onExpenseAction: onExpenseAction,
                onVoiceAction: {
                    // 语音操作，根据上下文决定收入或支出
                    // TODO: 可以显示选择菜单或默认为支出
                    onVoiceExpenseAction?()
                }
            )
            
            // Quick category selection
            QuickCategoryRow()
        }
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Circular Action Layout
struct CircularActionLayout: View {
    let onIncomeAction: () -> Void
    let onExpenseAction: () -> Void
    let onVoiceAction: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            let centerSize: CGFloat = 80
            let buttonSize: CGFloat = 60
            let radius: CGFloat = 85
            
            ZStack {
                // Center circle
                CenterActionButton(
                    size: centerSize,
                    isPressed: $isPressed,
                    onVoiceAction: onVoiceAction
                )
                
                // Income button (left)
                CircularActionButton(
                    title: "记收入",
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    size: buttonSize,
                    action: onIncomeAction
                )
                .position(
                    x: geometry.size.width / 2 - radius,
                    y: geometry.size.height / 2
                )
                
                // Expense button (right)
                CircularActionButton(
                    title: "记支出",
                    icon: "arrow.up.circle.fill",
                    color: .red,
                    size: buttonSize,
                    action: onExpenseAction
                )
                .position(
                    x: geometry.size.width / 2 + radius,
                    y: geometry.size.height / 2
                )
                
                // Voice button (top)
                CircularActionButton(
                    title: "语音记录",
                    icon: "mic.circle.fill",
                    color: .blue,
                    size: buttonSize,
                    action: onVoiceAction
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2 - radius
                )
                
                // Manual input hint (bottom)
                VStack(spacing: 2) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("手动输入")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2 + radius
                )
            }
        }
        .frame(height: 220)
    }
}

// MARK: - Center Action Button
struct CenterActionButton: View {
    let size: CGFloat
    @Binding var isPressed: Bool
    let onVoiceAction: () -> Void
    
    var body: some View {
        Button(action: onVoiceAction) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemGray5),
                                Color(.systemGray6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("记账")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
    }
}

// MARK: - Circular Action Button
struct CircularActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.6),
                                color.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(
                        color: color.opacity(0.3),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
    }
}

// MARK: - Quick Category Row
struct QuickCategoryRow: View {
    private let quickCategories = [
        ("🍽️", "餐饮"),
        ("🚗", "交通"),
        ("🛍️", "购物"),
        ("🏠", "住房"),
        ("💼", "工资")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("常用类别")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ForEach(Array(quickCategories.enumerated()), id: \.offset) { index, category in
                    QuickCategoryButton(
                        icon: category.0,
                        name: category.1
                    )
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - Quick Category Button
struct QuickCategoryButton: View {
    let icon: String
    let name: String
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // TODO: 快速选择类别逻辑
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            VStack(spacing: 2) {
                Text(icon)
                    .font(.system(size: 16))
                Text(name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
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
        onExpenseAction: { print("Add expense") },
        onIncomeAction: { print("Add income") },
        onVoiceExpenseAction: { print("Voice expense") },
        onVoiceIncomeAction: { print("Voice income") }
    )
}

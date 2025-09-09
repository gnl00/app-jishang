//
//  SummaryCardView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

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
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
                .padding()
            )
            .frame(height: 100)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
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
        HStack(spacing: 12) {
            ActionButtonView(
                title: "记收入",
                icon: "plus.circle.fill",
                borderColor: .blue,
                iconColor: .blue,
                textColor: .primary,
                action: onIncomeAction,
                longPressAction: onVoiceIncomeAction
            )

            ActionButtonView(
                title: "记支出",
                icon: "minus.circle.fill",
                borderColor: .red,
                iconColor: .red,
                textColor: .primary,
                action: onExpenseAction,
                longPressAction: onVoiceExpenseAction
            )
        }
        .padding(.horizontal)
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

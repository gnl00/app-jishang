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
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 2)
                )
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(iconColor)
                        
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textColor)
                    }
                    .padding()
                )
                .frame(height: 100)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SummaryCardsView: View {
    let onExpenseAction: () -> Void
    let onIncomeAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ActionButtonView(
                title: "记收入",
                icon: "plus.circle.fill",
                borderColor: .blue,
                iconColor: .blue,
                textColor: .primary,
                action: onIncomeAction
            )

            ActionButtonView(
                title: "记支出",
                icon: "minus.circle.fill",
                borderColor: .red,
                iconColor: .red,
                textColor: .primary,
                action: onExpenseAction
            )
        }
        .padding(.horizontal)
    }
}

#Preview {
    SummaryCardsView(
        onExpenseAction: { print("Add expense") },
        onIncomeAction: { print("Add income") }
    )
}

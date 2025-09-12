//
//  RollingNumberView.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - RollingNumberView: Main rolling number animation component
//  - DigitRollingView: Individual digit rolling animation
//  - Animation configuration and utilities
//

import SwiftUI
import Pow

// MARK: - Rolling Number Animation Components

struct DigitRollingView: View {
    let digit: Int
    let font: Font
    let textColor: Color
    
    @State private var displayedDigit: Int = 0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Current digit
            Text("\(displayedDigit)")
                .font(font)
                .foregroundColor(textColor)
                .offset(y: offset)
            
            // Next digit (for animation)
            if displayedDigit != digit {
                Text("\(digit)")
                    .font(font)
                    .foregroundColor(textColor)
                    .offset(y: offset + (digit > displayedDigit ? 20 : -20))
            }
        }
        .clipped()
        .onChange(of: digit) { _, newDigit in
            // 使用 Pow 的 boing 效果进行更有趣的过渡
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                let direction: CGFloat = newDigit > displayedDigit ? -20 : 20
                offset = direction
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                displayedDigit = newDigit
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
        }
        .onAppear {
            displayedDigit = digit
        }
    }
}

struct RollingNumberView: View {
    let value: Double
    let font: Font
    let textColor: Color
    let prefix: String
    let showDecimals: Bool
    // Configurable widths
    let digitWidth: CGFloat
    let decimalPointWidth: CGFloat
    let separatorWidth: CGFloat
    let currencyUnitWidth: CGFloat
    
    @State private var animatedValue: Double = 0
    
    init(
        value: Double,
        font: Font = .system(size: 18, weight: .bold, design: .rounded),
        textColor: Color = .primary,
        prefix: String = "",
        showDecimals: Bool = true,
        digitWidth: CGFloat = 16,
        decimalPointWidth: CGFloat = 8,
        separatorWidth: CGFloat = 8,
        currencyUnitWidth: CGFloat = 20
    ) {
        self.value = value
        self.font = font
        self.textColor = textColor
        self.prefix = prefix
        self.showDecimals = showDecimals
        self.digitWidth = digitWidth
        self.decimalPointWidth = decimalPointWidth
        self.separatorWidth = separatorWidth
        self.currencyUnitWidth = currencyUnitWidth
    }
    
    private var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.maximumFractionDigits = showDecimals ? 2 : 0
        formatter.minimumFractionDigits = showDecimals ? 2 : 0
        
        let formatted = formatter.string(from: NSNumber(value: abs(animatedValue))) ?? "0"
        let sign = animatedValue < 0 ? "-" : ""
        return "\(sign)\(prefix)\(formatted)"
    }
    
    private var digits: [String] {
        return formattedValue.compactMap { char in
            return String(char)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(digits.enumerated()), id: \.offset) { index, character in
                if character.first?.isNumber == true {
                    DigitRollingView(
                        digit: Int(character) ?? 0,
                        font: font,
                        textColor: textColor
                    )
                    .frame(width: digitWidth) // 数字宽度（可配置）
                } else {
                    Text(character)
                        .font(font)
                        .foregroundColor(textColor)
                        .frame(width: {
                            // 根据字符类型分配不同宽度
                            if character == "." { return decimalPointWidth }
                            if character == "¥" || character == "$" { return currencyUnitWidth } // 货币符号需要更宽
                            if character == "," { return separatorWidth } // 千分位分隔符
                            return 12 // 其他符号默认宽度
                        }())
                }
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = newValue
            }
        }
        .onAppear {
            animatedValue = value
        }
    }
}
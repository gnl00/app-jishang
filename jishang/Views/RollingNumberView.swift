//
//  RollingNumberView.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//
//  Rewritten to provide per-digit rolling animations that traverse all
//  intermediate digits and consistent layout widths for every number slot.
//

import SwiftUI

// MARK: - Supporting Models

private enum DigitPosition: Hashable {
    case integer(Int)   // 0 = units, 1 = tens, ...
    case fractional(Int) // 1 = tenths, 2 = hundredths, ...

    var key: String {
        switch self {
        case .integer(let index):
            return "i\(index)"
        case .fractional(let index):
            return "f\(index)"
        }
    }
}

private struct DigitInstruction: Equatable {
    let startDigit: Int
    let targetDigit: Int
    let stepCount: Int
}

private struct NumberToken: Identifiable, Equatable {
    enum Kind: Equatable {
        case digit(DigitPosition)
        case symbol(String)
    }

    let id: String
    let kind: Kind
}

private struct FormattedNumber {
    let tokens: [NumberToken]
    let digits: [DigitPosition: Int]
    let symbolCharacters: Set<Character>
    let decimalSeparator: Character?
    let groupingSeparator: Character?
}

private enum ValueDirection {
    case up
    case down
    case none
}

// MARK: - Digit Column View

private struct DigitRollingColumn: View {
    let instruction: DigitInstruction
    let font: Font
    let textColor: Color
    let digitSize: CGSize
    let stepDuration: Double

    @State private var progress: Double = 1

    private var height: CGFloat { max(digitSize.height, 1) }

    var body: some View {
        let steps = instruction.stepCount
        let direction = steps >= 0 ? 1 : -1
        let totalSteps = abs(steps)
        let clampedProgress = max(0, min(progress, 1))
        let traveled = Double(totalSteps) * clampedProgress
        let completedSteps = Int(traveled.rounded(.down))
        let fraction = traveled - Double(completedSteps)

        let baseDigit = instruction.startDigit
        let activeDigit = normalizedDigit(baseDigit + direction * completedSteps)
        let nextDigit = normalizedDigit(activeDigit + direction)

        let offset = CGFloat(direction) * -CGFloat(fraction) * height
        let showTransition = totalSteps > 0 && fraction > .ulpOfOne

        ZStack {
            Text("\(activeDigit)")
                .font(font)
                .monospacedDigit()
                .foregroundColor(textColor)
                .frame(width: digitSize.width, height: digitSize.height)
                .offset(y: offset)

            if showTransition {
                Text("\(nextDigit)")
                    .font(font)
                    .monospacedDigit()
                    .foregroundColor(textColor)
                    .frame(width: digitSize.width, height: digitSize.height)
                    .offset(y: offset + CGFloat(direction) * height)
            }
        }
        .clipped()
        .onAppear {
            initializeProgress(for: instruction)
            animateProgress(for: instruction)
        }
        .onChange(of: instruction) { _, newValue in
            initializeProgress(for: newValue)
            animateProgress(for: newValue)
        }
    }

    private func initializeProgress(for instruction: DigitInstruction) {
        let steps = instruction.stepCount
        withTransaction(SwiftUI.Transaction(animation: nil)) {
            progress = steps == 0 ? 1 : 0
        }
    }

    private func animateProgress(for instruction: DigitInstruction) {
        let steps = instruction.stepCount
        guard steps != 0 else { return }

        let duration = stepDuration * Double(abs(steps))
        withAnimation(.linear(duration: duration)) {
            progress = 1
        }
    }

    private func normalizedDigit(_ value: Int) -> Int {
        ((value % 10) + 10) % 10
    }
}

// MARK: - Metrics Helpers

private struct CharacterSizePreferenceKey: PreferenceKey {
    static var defaultValue: [Character: CGSize] = [:]

    static func reduce(value: inout [Character: CGSize], nextValue: () -> [Character: CGSize]) {
        let newValue = nextValue()
        for (character, size) in newValue {
            let existing = value[character] ?? .zero
            let maxWidth = max(existing.width, size.width)
            let maxHeight = max(existing.height, size.height)
            value[character] = CGSize(width: maxWidth, height: maxHeight)
        }
    }
}

private struct CharacterMetricsProbe: View {
    let characters: Set<Character>
    let font: Font

    var body: some View {
        ZStack {
            ForEach(Array(characters), id: \.self) { character in
                Text(String(character))
                    .font(font)
                    .monospacedDigit()
                    .fixedSize()
                    .opacity(0)
                    .overlay(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: CharacterSizePreferenceKey.self,
                                value: [character: proxy.size]
                            )
                        }
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Rolling Number View

struct RollingNumberView: View {
    let value: Double
    let font: Font
    let textColor: Color
    let prefix: String
    let showDecimals: Bool

    private let digitWidthFallback: CGFloat
    private let decimalWidthFallback: CGFloat
    private let separatorWidthFallback: CGFloat
    private let currencyWidthFallback: CGFloat
    private let stepDuration: Double = 0.08

    @State private var previousValue: Double
    @State private var formatted: FormattedNumber
    @State private var digitInstructions: [DigitPosition: DigitInstruction]
    @State private var characterSizes: [Character: CGSize] = [:]

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
        self.digitWidthFallback = digitWidth
        self.decimalWidthFallback = decimalPointWidth
        self.separatorWidthFallback = separatorWidth
        self.currencyWidthFallback = currencyUnitWidth

        let formatted = RollingNumberView.format(value: value, prefix: prefix, showDecimals: showDecimals)
        _formatted = State(initialValue: formatted)
        _digitInstructions = State(initialValue: RollingNumberView.initialInstructions(for: formatted))
        _previousValue = State(initialValue: value)
    }

    var body: some View {
        let measurementCharacters = measurementSet()
        let digitSize = calculatedDigitSize()
        let decimalWidth = calculatedDecimalWidth(defaultDigitWidth: digitSize.width)
        let separatorWidth = calculatedSeparatorWidth(defaultDigitWidth: digitSize.width)

        HStack(spacing: 0) {
            ForEach(formatted.tokens) { token in
                switch token.kind {
                case .symbol(let symbol):
                    symbolView(symbol: symbol, digitSize: digitSize, decimalWidth: decimalWidth, separatorWidth: separatorWidth)
                case .digit(let position):
                    let currentDigit = formatted.digits[position] ?? 0
                    let instruction = digitInstructions[position] ?? DigitInstruction(
                        startDigit: currentDigit,
                        targetDigit: currentDigit,
                        stepCount: 0
                    )
                    DigitRollingColumn(
                        instruction: instruction,
                        font: font,
                        textColor: textColor,
                        digitSize: digitSize,
                        stepDuration: stepDuration
                    )
                }
            }
        }
        .background(
            CharacterMetricsProbe(
                characters: measurementCharacters,
                font: font
            )
        )
        .onPreferenceChange(CharacterSizePreferenceKey.self) { sizes in
            characterSizes.merge(sizes) { _, new in new }
        }
        .onChange(of: value) { _, newValue in
            updateState(for: newValue)
        }
    }

    // MARK: - Token Views

    private func symbolView(symbol: String, digitSize: CGSize, decimalWidth: CGFloat, separatorWidth: CGFloat) -> some View {
        let character = symbol.first ?? " "
        let width: CGFloat

        if let decimal = formatted.decimalSeparator, character == decimal {
            width = decimalWidth
        } else if let grouping = formatted.groupingSeparator, character == grouping {
            width = separatorWidth
        } else if character == "-" {
            width = max(characterSizes[character]?.width ?? 0, digitSize.width)
        } else if prefix.contains(character) {
            let fallback = max(currencyWidthFallback, digitSize.width)
            width = max(characterSizes[character]?.width ?? 0, fallback)
        } else {
            width = max(characterSizes[character]?.width ?? 0, digitSize.width * 0.6)
        }

        return Text(symbol)
            .font(font)
            .monospacedDigit()
            .foregroundColor(textColor)
            .frame(width: width, height: digitSize.height)
    }

    // MARK: - Formatting Helpers

    private static func format(value: Double, prefix: String, showDecimals: Bool) -> FormattedNumber {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = showDecimals ? 2 : 0
        formatter.maximumFractionDigits = showDecimals ? 2 : 0

        let absoluteValue = abs(value)
        let formattedString = formatter.string(from: NSNumber(value: absoluteValue)) ?? "0"
        let decimalSeparatorString = formatter.decimalSeparator ?? "."
        let groupingSeparatorString = formatter.groupingSeparator ?? ","

        let components = formattedString.components(separatedBy: decimalSeparatorString)
        let integerPart = components.first ?? "0"
        let fractionPart = components.count > 1 ? components[1] : ""

        var tokens: [NumberToken] = []
        var digits: [DigitPosition: Int] = [:]
        var symbols: Set<Character> = []

        if value < 0 {
            tokens.append(NumberToken(id: "sign", kind: .symbol("-")))
            symbols.insert("-")
        }

        for (index, char) in prefix.enumerated() {
            let symbol = String(char)
            tokens.append(NumberToken(id: "prefix-\(index)", kind: .symbol(symbol)))
            symbols.insert(char)
        }

        let integerCharacters = Array(integerPart)
        var integerMapping: [Int: DigitPosition] = [:]
        var digitIndex = 0
        for (index, char) in integerCharacters.enumerated().reversed() {
            if char.isNumber {
                let position = DigitPosition.integer(digitIndex)
                integerMapping[index] = position
                digits[position] = Int(String(char)) ?? 0
                digitIndex += 1
            }
        }

        for (index, char) in integerCharacters.enumerated() {
            if let position = integerMapping[index] {
                tokens.append(NumberToken(id: "digit-\(position.key)", kind: .digit(position)))
            } else {
                let symbol = String(char)
                tokens.append(NumberToken(id: "separator-int-\(index)", kind: .symbol(symbol)))
                if let first = symbol.first { symbols.insert(first) }
            }
        }

        if showDecimals {
            tokens.append(NumberToken(id: "decimal-separator", kind: .symbol(decimalSeparatorString)))
            if let first = decimalSeparatorString.first { symbols.insert(first) }

            let fractionCharacters = Array(fractionPart)
            for (index, char) in fractionCharacters.enumerated() {
                if char.isNumber {
                    let position = DigitPosition.fractional(index + 1)
                    digits[position] = Int(String(char)) ?? 0
                    tokens.append(NumberToken(id: "digit-\(position.key)", kind: .digit(position)))
                } else {
                    let symbol = String(char)
                    tokens.append(NumberToken(id: "separator-frac-\(index)", kind: .symbol(symbol)))
                    if let first = symbol.first { symbols.insert(first) }
                }
            }
        }

        return FormattedNumber(
            tokens: tokens,
            digits: digits,
            symbolCharacters: symbols,
            decimalSeparator: decimalSeparatorString.first,
            groupingSeparator: groupingSeparatorString.first
        )
    }

    private static func initialInstructions(for formatted: FormattedNumber) -> [DigitPosition: DigitInstruction] {
        var map: [DigitPosition: DigitInstruction] = [:]
        for (position, digit) in formatted.digits {
            map[position] = DigitInstruction(startDigit: digit, targetDigit: digit, stepCount: 0)
        }
        return map
    }

    private func updateState(for newValue: Double) {
        let newFormatted = RollingNumberView.format(value: newValue, prefix: prefix, showDecimals: showDecimals)
        let direction = determineDirection(newValue: newValue)
        let instructions = RollingNumberView.buildInstructions(
            from: formatted,
            to: newFormatted,
            direction: direction
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            formatted = newFormatted
            digitInstructions = instructions
        }
        previousValue = newValue
    }

    private func determineDirection(newValue: Double) -> ValueDirection {
        if newValue == previousValue { return .none }
        return newValue > previousValue ? .up : .down
    }

    private static func buildInstructions(
        from oldFormatted: FormattedNumber,
        to newFormatted: FormattedNumber,
        direction: ValueDirection
    ) -> [DigitPosition: DigitInstruction] {
        var result: [DigitPosition: DigitInstruction] = [:]
        let oldDigits = oldFormatted.digits

        for (position, newDigit) in newFormatted.digits {
            let fallbackStart: Int
            switch direction {
            case .up:
                fallbackStart = 0
            case .down:
                fallbackStart = newDigit
            case .none:
                fallbackStart = newDigit
            }

            let startDigit = oldDigits[position] ?? fallbackStart
            let steps: Int

            switch direction {
            case .none:
                steps = 0
            case .up:
                steps = forwardSteps(from: startDigit, to: newDigit)
            case .down:
                steps = -forwardSteps(from: newDigit, to: startDigit)
            }

            result[position] = DigitInstruction(
                startDigit: startDigit,
                targetDigit: newDigit,
                stepCount: steps
            )
        }

        return result
    }

    private static func forwardSteps(from start: Int, to end: Int) -> Int {
        let difference = ((end - start) % 10 + 10) % 10
        return difference
    }

    // MARK: - Measurement Helpers

    private func measurementSet() -> Set<Character> {
        var characters: Set<Character> = Set("0123456789")
        characters.formUnion(formatted.symbolCharacters)
        if let decimal = formatted.decimalSeparator { characters.insert(decimal) }
        if let grouping = formatted.groupingSeparator { characters.insert(grouping) }
        if value < 0 { characters.insert("-") }
        characters.formUnion(prefix)
        return characters
    }

    private func calculatedDigitSize() -> CGSize {
        let digits: [Character] = Array("0123456789")
        let maxWidth = digits
            .compactMap { characterSizes[$0]?.width }
            .max() ?? digitWidthFallback
        let fallbackHeight = digitWidthFallback * 1.6
        let height = characterSizes["0"]?.height ?? fallbackHeight
        return CGSize(width: max(maxWidth, digitWidthFallback), height: height)
    }

    private func calculatedDecimalWidth(defaultDigitWidth: CGFloat) -> CGFloat {
        guard let decimal = formatted.decimalSeparator else {
            return decimalWidthFallback
        }
        let measured = characterSizes[decimal]?.width ?? 0
        return max(measured, decimalWidthFallback, defaultDigitWidth * 0.6)
    }

    private func calculatedSeparatorWidth(defaultDigitWidth: CGFloat) -> CGFloat {
        guard let separator = formatted.groupingSeparator else {
            return separatorWidthFallback
        }
        let measured = characterSizes[separator]?.width ?? 0
        return max(measured, separatorWidthFallback, defaultDigitWidth * 0.6)
    }
}

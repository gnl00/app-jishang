//
//  MonthlySummaryView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//  
//  Contains:
//  - MonthlySummaryView: Monthly summary card for home page
//  - MonthSwitcherView: Month switcher component
//  - HeaderSectionView: Header with expand arrow
//

import SwiftUI
import Pow

struct MonthlySummaryView: View {
    @ObservedObject var store: TransactionStore
    @State private var selectedPeriod = 0
    @State private var isExpanded = false
    @State private var showDailyExpenseDetails = false
    
    private var selectedDate: Date {
        let calendar = Calendar.current
        if selectedPeriod == 0 {
            return Date()
        } else {
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }
    
    private var currentMonthIncome: Double {
        store.monthlyIncome(for: selectedDate)
    }
    
    private var currentMonthExpense: Double {
        store.monthlyExpense(for: selectedDate)
    }
    
    private var balance: Double {
        currentMonthIncome - currentMonthExpense
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - 简化设计，与SummaryCardsView呼应
            HStack {
                Text("月度总览")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showDailyExpenseDetails = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("详情")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 18)
            
            // 核心数据 - 三列平均分布，去除彩色背景
            HStack(spacing: 0) {
                // 收入
                VStack(spacing: 6) {
                    Text("收入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    RollingNumberView(
                        value: currentMonthIncome,
                        font: .system(size: 18, weight: .bold, design: .rounded),
                        textColor: .primary,
                        prefix: "¥",
                        showDecimals: false
                    )
                }
                .frame(maxWidth: .infinity)
                
                // 分隔线
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 1, height: 35)
                
                // 支出
                VStack(spacing: 6) {
                    Text("支出")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    RollingNumberView(
                        value: currentMonthExpense,
                        font: .system(size: 18, weight: .bold, design: .rounded),
                        textColor: .primary,
                        prefix: "¥",
                        showDecimals: false
                    )
                }
                .frame(maxWidth: .infinity)
                
                // 分隔线
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 1, height: 35)
                
                // 余额
                VStack(spacing: 6) {
                    Text("余额")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    RollingNumberView(
                        value: balance,
                        font: .system(size: 18, weight: .bold, design: .rounded),
                        textColor: balance >= 0 ? .primary : Color(red: 0.8, green: 0.3, blue: 0.3),
                        prefix: "¥",
                        showDecimals: false
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 20)
            
            // 进度条 - 保持红绿配色与SummaryCardsView呼应
            RedGreenProgressView(
                expense: currentMonthExpense,
                balance: balance,
                totalIncome: currentMonthIncome
            )
            .padding(.bottom, 18)
            
            // 月份切换器 - 简化设计
            MonthSwitcherView(selectedPeriod: $selectedPeriod)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .sheet(isPresented: $showDailyExpenseDetails) {
            MonthlyStatisticsView(store: store, monthDate: selectedDate)
        }
    }
}

// MARK: - Header Section with Title and Expand Arrow
struct HeaderSectionView: View {
    @Binding var isExpanded: Bool
    var onShowDetails: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Text("月度总览")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                onShowDetails?()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Month Switcher Section
struct MonthSwitcherView: View {
    @Binding var selectedPeriod: Int
    
    private let periodOptions = ["本月", "上个月"]
    
    var body: some View {
        GeometryReader { geo in
            let height: CGFloat = 32
            let corner: CGFloat = 20
            let bgColor = Color(.systemGray6)
            let borderColor = Color(.systemGray5)
            let count = max(periodOptions.count, 1)
            let segmentWidth = geo.size.width / CGFloat(count)

            ZStack(alignment: .leading) {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: corner)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(borderColor, lineWidth: 1)
                    )

                // Selector bar with rounded corners
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .frame(width: segmentWidth - 4, height: height - 4)
                    .padding(2)
                    .offset(x: CGFloat(selectedPeriod) * segmentWidth)
                    .animation(.easeInOut(duration: 0.25), value: selectedPeriod)

                // Segments
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedPeriod = index
                            }
                        }) {
                            Text(periodOptions[index])
                                .font(.system(size: 14, weight: selectedPeriod == index ? .semibold : .regular))
                                .foregroundColor(selectedPeriod == index ? .primary : .secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: segmentWidth, height: height)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(height: height)
        }
        .frame(height: 32)
        .padding(.top, 4)
    }
}

#Preview {
    MonthlySummaryView(store: TransactionStore())
}

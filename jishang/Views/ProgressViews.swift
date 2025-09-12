//
//  ProgressViews.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - RedGreenProgressView: Red and green progress bar component
//  - ImprovedProgressView: Legacy improved progress view
//  - CostBalanceProgressView: Legacy cost balance progress view
//  - Progress bar utilities and helpers
//

import SwiftUI

// MARK: - Red Green Progress View (与SummaryCardsView配色呼应)
struct RedGreenProgressView: View {
    let expense: Double
    let balance: Double
    let totalIncome: Double
    
    private var expenseRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(expense / totalIncome, 1.0)
    }
    
    private var balanceRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(max((totalIncome - expense) / totalIncome, 0), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度条 - 使用与SummaryCardsView相同的红绿配色
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 20)
                    
                    HStack(spacing: 0) {
                        // 支出部分 - 使用红色，与"记支出"按钮呼应
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.6),
                                        Color.red.opacity(0.4)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * expenseRatio, height: 20)
                            .animation(.easeInOut(duration: 0.8), value: expenseRatio)
                        
                        // 余额部分 - 使用绿色，与"记收入"按钮呼应
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.4),
                                        Color.green.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * balanceRatio, height: 20)
                            .animation(.easeInOut(duration: 0.8), value: balanceRatio)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 标签和百分比
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("支出 \(String(format: "%.1f", expenseRatio * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("余额 \(String(format: "%.1f", balanceRatio * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Improved Progress View (Legacy)
struct ImprovedProgressView: View {
    let expense: Double
    let balance: Double
    let totalIncome: Double
    
    private var expenseRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(expense / totalIncome, 1.0)
    }
    
    private var balanceRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(max((totalIncome - expense) / totalIncome, 0), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 24)
                    
                    HStack(spacing: 0) {
                        // 支出部分
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * expenseRatio, height: 24)
                            .animation(.easeInOut(duration: 0.8), value: expenseRatio)
                        
                        // 余额部分
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * balanceRatio, height: 24)
                            .animation(.easeInOut(duration: 0.8), value: balanceRatio)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 标签和百分比
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text("支出占比: \(String(format: "%.1f", expenseRatio * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text("余额占比: \(String(format: "%.1f", balanceRatio * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Cost and Balance Progress Section (Legacy)
struct CostBalanceProgressView: View {
    let expense: Double
    let balance: Double
    let totalIncome: Double
    
    private var expenseRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(expense / totalIncome, 1.0)
    }
    
    private var balanceRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return min(max((totalIncome - expense) / totalIncome, 0), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部标签（仅文案）
            HStack {
                Text("花销")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("余额")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // 血条样式的进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条（总收入）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .frame(height: 28)
                    
                    HStack(spacing: 0) {
                        // Cost部分（淡红色）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.6))
                            .frame(width: geometry.size.width * expenseRatio, height: 28)
                            .animation(.easeInOut(duration: 0.8), value: expenseRatio)
                        
                        // Balance部分（淡蓝色）
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: geometry.size.width * balanceRatio, height: 28)
                            .animation(.easeInOut(duration: 0.8), value: balanceRatio)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 数字显示（保留在进度条下方）
            HStack {
                RollingNumberView(
                    value: expense,
                    font: .system(size: 12, weight: .regular, design: .rounded),
                    textColor: .red,
                    prefix: "¥",
                    digitWidth: 12,
                    decimalPointWidth: 6,
                    separatorWidth: 6
                )
                
                Spacer()
                
                RollingNumberView(
                    value: balance,
                    font: .system(size: 12, weight: .regular, design: .rounded),
                    textColor: balance >= 0 ? .blue : .red,
                    prefix: "¥",
                    digitWidth: 12,
                    decimalPointWidth: 6,
                    separatorWidth: 6
                )
            }
        }
    }
}
//
//  MonthlyStatisticsComponents.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - EmptyDataView: Empty state view for MonthlyStatisticsView
//  - AbnormalSpendingAlert: Alert component for abnormal spending patterns
//  - Other components specific to MonthlyStatisticsView
//

import SwiftUI

// MARK: - Empty Data View (for Monthly Statistics)
struct EmptyDataView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    init(
        title: String = "暂无支出数据", 
        subtitle: String = "开始记录你的第一笔消费吧",
        systemImage: String = "chart.bar"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray6), lineWidth: 1)
                )
        )
    }
}

// MARK: - Abnormal Spending Alert
struct AbnormalSpendingAlert: View {
    let category: Category
    let change: Double
    let percentage: Double
    
    private var alertMessage: String {
        if change > 50 {
            return "⚠️ 异常提醒: \(category.name)支出比上月增长\(String(format: "%.0f", change))%，建议适当控制"
        } else if percentage > 60 {
            return "⚠️ 异常提醒: \(category.name)支出占比过高（\(String(format: "%.1f", percentage))%），建议合理分配"
        } else {
            return "⚠️ 提醒: 请关注\(category.name)支出变化"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(alertMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview("EmptyDataView") {
    EmptyDataView()
        .padding()
}

#Preview("AbnormalSpendingAlert") {
    AbnormalSpendingAlert(
        category: Category.food,
        change: 60,
        percentage: 65
    )
    .padding()
}
//
//  SettingsView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    SettingRow(
                        icon: "person.circle",
                        title: "个人资料",
                        showArrow: true
                    ) {
                        // Handle profile tap
                    }
                    
                    SettingRow(
                        icon: "bell",
                        title: "通知设置",
                        showArrow: true
                    ) {
                        // Handle notifications tap
                    }
                }
                
                Section {
                    SettingRow(
                        icon: "doc.text",
                        title: "数据导出",
                        showArrow: true
                    ) {
                        // Handle export tap
                    }
                    
                    SettingRow(
                        icon: "arrow.clockwise",
                        title: "数据备份",
                        showArrow: true
                    ) {
                        // Handle backup tap
                    }
                    
                    SettingRow(
                        icon: "trash",
                        title: "清空数据",
                        showArrow: true,
                        textColor: .red
                    ) {
                        // Handle clear data tap
                    }
                }
                
                Section {
                    SettingRow(
                        icon: "questionmark.circle",
                        title: "帮助与反馈",
                        showArrow: true
                    ) {
                        // Handle help tap
                    }
                    
                    SettingRow(
                        icon: "star",
                        title: "评价应用",
                        showArrow: true
                    ) {
                        // Handle rate app tap
                    }
                }
                
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Text("不如就记上一笔")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("版本 1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let showArrow: Bool
    let textColor: Color
    let action: () -> Void
    
    init(icon: String, title: String, showArrow: Bool = false, textColor: Color = .primary, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.showArrow = showArrow
        self.textColor = textColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                
                Spacer()
                
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}

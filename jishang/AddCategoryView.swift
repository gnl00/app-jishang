//
//  AddCategoryView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct AddCategoryView: View {
    @ObservedObject var store: TransactionStore
    @Binding var isPresented: Bool
    let transactionType: TransactionType
    @Binding var selectedCategory: Category?
    
    @State private var categoryName: String = ""
    @State private var categoryIcon: String = "📝"
    @FocusState private var isNameFocused: Bool
    
    private let defaultIcons = [
        "🍽️", "🚗", "🛍️", "🎬", "🏥", "📚", "🏠", "💼", "🎁", "📈",
        "✈️", "⚽", "💻", "📱", "🎵", "📺", "👕", "☕", "🍕", "🏋️"
    ]
    
    private var isValidInput: Bool {
        return !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("添加新类别")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    // Category Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("类别名称")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("输入类别名称", text: $categoryName)
                            .font(.system(size: 16))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isNameFocused)
                    }
                    
                    // Icon Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择图标")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(defaultIcons, id: \.self) { icon in
                                Button(action: {
                                    categoryIcon = icon
                                }) {
                                    Text(icon)
                                        .font(.system(size: 24))
                                        .frame(width: 50, height: 50)
                                        .background(categoryIcon == icon ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(categoryIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                    
                    // Transaction Type Info
                    HStack {
                        Text("类别类型:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(transactionType == .income ? "收入" : "支出")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(transactionType == .income ? .blue : .red)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("取消") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                    
                    Button("保存") {
                        saveCategoryAndSelect()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValidInput ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .disabled(!isValidInput)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onAppear {
            isNameFocused = true
        }
    }
    
    private func saveCategoryAndSelect() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        store.addCustomCategory(
            name: trimmedName,
            icon: categoryIcon,
            defaultType: transactionType
        )
        
        // 选择刚创建的类别
        if let newCategory = store.customCategories.last {
            selectedCategory = newCategory
        }
        
        isPresented = false
    }
}

#Preview {
    AddCategoryView(
        store: TransactionStore(),
        isPresented: .constant(true),
        transactionType: .expense,
        selectedCategory: .constant(nil)
    )
}
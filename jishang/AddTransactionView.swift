//
//  AddTransactionView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct AddTransactionView: View {
    @ObservedObject var store: TransactionStore
    @Binding var isPresented: Bool
    @State var transactionType: TransactionType
    
    @State private var amount: String = ""
    @State private var selectedCategory: Category = .food
    @State private var note: String = ""
    @State private var date = Date()
    @FocusState private var isAmountFocused: Bool
    
    private var filteredCategories: [Category] {
        Category.allCases.filter { category in
            if transactionType == .income {
                return [.salary, .bonus, .investment, .other].contains(category)
            } else {
                return ![.salary, .bonus, .investment].contains(category)
            }
        }
    }
    
    private var isValidInput: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Transaction Type Header
                HStack {
                    Image(systemName: transactionType == .income ? "plus.circle.fill" : "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(transactionType == .income ? .blue : .red)
                    
                    Text(transactionType == .income ? "添加收入" : "添加支出")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    // Amount Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("金额")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("¥")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("0.00", text: $amount)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .focused($isAmountFocused)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(filteredCategories, id: \.self) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    
                    // Note Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("添加备注...", text: $note)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Date Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("日期")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        DatePicker("选择日期", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
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
                        saveTransaction()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValidInput ? (transactionType == .income ? Color.blue : Color.red) : Color.gray)
                    .cornerRadius(12)
                    .disabled(!isValidInput)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onAppear {
            selectedCategory = filteredCategories.first ?? .food
            isAmountFocused = true
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        
        let transaction = Transaction(
            amount: amountValue,
            category: selectedCategory,
            type: transactionType,
            date: date,
            note: note
        )
        
        store.addTransaction(transaction)
        isPresented = false
    }
}

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.system(size: 20))
                
                Text(category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    AddTransactionView(
        store: TransactionStore(),
        isPresented: .constant(true),
        transactionType: .expense
    )
}
//
//  AddTransactionView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct AddTransactionView: View {
    @ObservedObject var store: TransactionStore
    @Binding var editingTransaction: Transaction? // 绑定到parent的editingTransaction
    let transactionType: TransactionType
    let initialTransaction: Transaction? // 初始编辑的交易数据
    
    @State private var amount: String = ""
    @State private var selectedCategory: Category?
    @State private var note: String = ""
    @State private var date = Date()
    @State private var showAddCategory = false
    @FocusState private var isAmountFocused: Bool
    
    init(store: TransactionStore, editingTransaction: Binding<Transaction?>, transactionType: TransactionType, initialTransaction: Transaction? = nil) {
        self.store = store
        self._editingTransaction = editingTransaction
        self.transactionType = transactionType
        self.initialTransaction = initialTransaction
    }
    
    // 兼容性构造器，用于新增交易（非编辑场景）
    init(store: TransactionStore, isPresented: Binding<Bool>, transactionType: TransactionType) {
        self.store = store
        self._editingTransaction = Binding(
            get: { nil },
            set: { _ in isPresented.wrappedValue = false }
        )
        self.transactionType = transactionType
        self.initialTransaction = nil
    }
    
    private var filteredCategories: [Category] {
        store.allCategories.filter { category in
            if transactionType == .income {
                return category.defaultType == .income || category.isCustom
            } else {
                return category.defaultType == .expense || category.isCustom
            }
        }
    }
    
    private var isValidInput: Bool {
        guard let amountValue = Double(amount), amountValue > 0,
              let _ = selectedCategory else {
            return false
        }
        return true
    }
    
    private var isEditing: Bool {
        return initialTransaction != nil
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Transaction Type Header
                HStack {
                    Image(systemName: transactionType == .income ? "plus.circle.fill" : "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(transactionType == .income ? .blue : .red)
                    
                    Text(isEditing ? (transactionType == .income ? "编辑收入" : "编辑支出") : (transactionType == .income ? "添加收入" : "添加支出"))
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
                            ForEach(filteredCategories, id: \.id) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id
                                ) {
                                    selectedCategory = category
                                }
                            }
                            
                            // 添加类别按钮
                            Button(action: {
                                showAddCategory = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                    
                                    Text("添加")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                }
                                .frame(height: 60)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
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
                        editingTransaction = nil
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                    
                    Button(isEditing ? "更新" : "保存") {
                        saveTransaction()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValidInput ? (Color.green) : Color.gray)
                    .cornerRadius(12)
                    .disabled(!isValidInput)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView(
                store: store,
                isPresented: $showAddCategory,
                transactionType: transactionType,
                selectedCategory: $selectedCategory
            )
        }
        .onAppear {
            if let editing = initialTransaction {
                // 编辑模式：预填充数据
                amount = String(editing.amount)
                selectedCategory = editing.category
                note = editing.note
                date = editing.date
            } else {
                // 新增模式：设置默认分类
                if selectedCategory == nil {
                    selectedCategory = filteredCategories.first
                }
                isAmountFocused = true
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0,
              let category = selectedCategory else { return }
        
        if let editing = initialTransaction {
            // 编辑模式：更新现有交易
            var updatedTransaction = editing
            updatedTransaction.amount = amountValue
            updatedTransaction.category = category
            updatedTransaction.note = note
            updatedTransaction.date = date
            // 注意：保持原有的id和type不变
            store.updateTransaction(updatedTransaction)
        } else {
            // 新增模式：创建新交易
            let transaction = Transaction(
                amount: amountValue,
                category: category,
                type: transactionType,
                date: date,
                note: note
            )
            store.addTransaction(transaction)
        }
        
        editingTransaction = nil
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

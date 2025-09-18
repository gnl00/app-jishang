//
//  AddTransactionView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI
import UIKit
import Pow

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
    @State private var isDeleteMode = false
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
                return category.defaultType == .income
            } else {
                return category.defaultType == .expense
            }
        }
    }

    // 分页逻辑：当分类数量超过8个时才分页，否则单页显示
    private var categoryPages: [[Category]] {
        let categories = filteredCategories

        // 如果分类少于等于8个，单页显示所有分类
        if categories.count <= 8 {
            return [categories]
        }

        // 分类较多时，每页8个分类（2行4列）
        let categoriesPerPage = 8
        var pages: [[Category]] = []

        for i in stride(from: 0, to: categories.count, by: categoriesPerPage) {
            let endIndex = min(i + categoriesPerPage, categories.count)
            let pageCategories = Array(categories[i..<endIndex])
            pages.append(pageCategories)
        }

        // 如果没有分类，至少要有一页
        if pages.isEmpty {
            pages.append([])
        }

        return pages
    }

    // 是否需要分页显示
    private var shouldUsePaging: Bool {
        return filteredCategories.count > 8
    }

    // 固定TabView高度：始终显示2行
    private var fixedTabViewHeight: CGFloat {
        return CGFloat(2 * 75) // 2行，每行75pt（60pt分类高度 + 15pt间距）
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
            VStack(spacing: 0) {
                // 固定顶部区域
                VStack(spacing: 20) {
                    headerSection
                    amountSection  // TextField 永远固定在可见区域
                }
                .padding(.horizontal)
                .padding(.top)
                .background(Color(.systemBackground))

                // 分页分类选择器
                pagedCategorySection
                    .padding(.top, 16)

                // 固定底部区域
                VStack(spacing: 16) {
                    noteSection
                    dateSection
                    actionButtons
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
            .transition(.slide.animation(.spring(response: 0.5, dampingFraction: 0.8)))
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
                // 优先使用当前store中的同ID分类；否则退化为按名称和类型匹配，确保高亮
                if let matchById = store.allCategories.first(where: { $0.id == editing.category.id }) {
                    selectedCategory = matchById
                } else if let matchByName = store.allCategories.first(where: { $0.name == editing.category.name && $0.defaultType == editing.type }) {
                    selectedCategory = matchByName
                } else {
                    selectedCategory = editing.category
                }
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
    
    private var headerSection: some View {
        HStack {
            Image(systemName: transactionType == .income ? "plus.circle.fill" : "minus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(transactionType == .income ? .blue : .red)
            
            Text(isEditing ? (transactionType == .income ? "编辑收入" : "编辑支出") : (transactionType == .income ? "添加收入" : "添加支出"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .transition(.slide)
            
            Spacer()
        }
        .padding(.top)
    }
    
    // 新的分页分类选择器
    private var pagedCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 分类标题
            HStack {
                Text("分类")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)

            // 分页视图（只展示分类）
            TabView {
                ForEach(0..<categoryPages.count, id: \.self) { pageIndex in
                    CategoryPageView(
                        categories: categoryPages[pageIndex],
                        selectedCategory: $selectedCategory,
                        isDeleteMode: $isDeleteMode,
                        onCategorySelected: { category in
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            selectedCategory = category
                        },
                        onDeleteCategory: { category in
                            store.deleteCategoryAndReassign(category)
                            if selectedCategory?.id == category.id {
                                selectedCategory = filteredCategories.first
                            }
                        },
                        onAddCategory: {
                            showAddCategory = true
                        }
                    )
                    .tag(pageIndex)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: categoryPages.count > 1 ? .always : .never))
            .frame(height: fixedTabViewHeight) // 固定高度：始终2行
            .background(Color(.systemBackground))
            .onAppear {
                // 设置页面指示器颜色（淡蓝色主题）
                setupPageControlAppearance()
            }

            // 固定操作按钮区域（独立于分页）
            operationButtonsSection
        }
    }

    // 操作按钮区域
    private var operationButtonsSection: some View {
        HStack(spacing: 8) {
            // 添加类别按钮
            Button(action: {
                showAddCategory = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)

                    Text("添加分类")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }

            // 删除类别按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDeleteMode.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDeleteMode ? .white : .red)

                    Text("删除分类")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDeleteMode ? .white : .red)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(isDeleteMode ? Color.red : Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDeleteMode ? Color.red : Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var amountSection: some View {
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
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(filteredCategories, id: \.id) { category in
                    ZStack(alignment: .topTrailing) {
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            if !isDeleteMode {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                selectedCategory = category
                            }
                        }
                        
                        // 删除分类小按钮
                        if isDeleteMode && category.isCustom {
                            Button(action: {
                                // 删除分类，并将该分类下的交易置为空
                                store.deleteCategoryAndReassign(category)
                                // 如果当前选中的是该分类，清空选择
                                if selectedCategory?.id == category.id {
                                    // 重新选择一个可用分类（若存在）
                                    selectedCategory = filteredCategories.first
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.red)
                                    .background(Color(.systemBackground).opacity(0.9))
                                    .clipShape(Circle())
                                    .contentShape(Circle())
                                    .compositingGroup()
                            }
                            // 保持在卡片内部边距，避免被内容遮挡
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                            // 始终置于卡片之上，避免覆盖问题
                            .zIndex(1)
                            // 使用 Pow 的过渡，插入时 Glare，移除时 Iris 从右上角收缩并淡出
                            .transition(
                                .asymmetric(
                                    insertion: .movingParts.blinds(slatWidth: 12, style: .venetian, isStaggered: true),
                                    removal: .movingParts.iris(origin: .topTrailing, blurRadius: 1)
                                        .combined(with: .opacity)
                                )
                            )
                            // 使用 Pow 的缓入指数动画，增强消失流畅度
                            .animation(.movingParts.easeInExponential(duration: 0.35), value: isDeleteMode)
                        }
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

                // 删除类别按钮（设计风格与“添加”一致）
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDeleteMode.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        
                        Text("删除")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .transition(.slide.combined(with: .scale))
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("添加备注...", text: $note)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .transition(.slide.combined(with: .opacity))
    }
    
    private var dateSection: some View {
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
        .transition(.slide.combined(with: .opacity))
    }
    
    private var actionButtons: some View {
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
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
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
        .transition(.slide.combined(with: .opacity))
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

    // MARK: - Page Control Appearance Setup
    private func setupPageControlAppearance() {
        // 设置页面指示器的外观，使用淡蓝色主题
        let pageControl = UIPageControl.appearance()

        // 设置当前页面指示器颜色（选中状态）- 使用淡蓝色
        pageControl.currentPageIndicatorTintColor = UIColor.systemBlue.withAlphaComponent(0.6)

        // 设置非当前页面指示器颜色（未选中状态）- 使用浅灰色
        pageControl.pageIndicatorTintColor = UIColor.systemGray4

        // 移除背景相关设置，背景由overlay处理
        pageControl.backgroundColor = UIColor.clear
        pageControl.preferredIndicatorImage = nil
    }
}

// MARK: - Category Page View
struct CategoryPageView: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @Binding var isDeleteMode: Bool

    let onCategorySelected: (Category) -> Void
    let onDeleteCategory: (Category) -> Void
    let onAddCategory: () -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            // 显示当前页的分类
            ForEach(categories, id: \.id) { category in
                ZStack(alignment: .topTrailing) {
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory?.id == category.id
                    ) {
                        if !isDeleteMode {
                            onCategorySelected(category)
                        }
                    }

                    // 删除分类小按钮
                    if isDeleteMode && category.isCustom {
                        Button(action: {
                            onDeleteCategory(category)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                                .background(Color(.systemBackground).opacity(0.9))
                                .clipShape(Circle())
                                .contentShape(Circle())
                                .compositingGroup()
                        }
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                        .zIndex(1)
                        .transition(
                            .asymmetric(
                                insertion: .movingParts.blinds(slatWidth: 12, style: .venetian, isStaggered: true),
                                removal: .movingParts.iris(origin: .topTrailing, blurRadius: 1)
                                    .combined(with: .opacity)
                            )
                        )
                        .animation(.movingParts.easeInExponential(duration: 0.35), value: isDeleteMode)
                    }
                }
            }

            // 填充占位按钮，始终保证2行8个位置
            let placeholderCount = max(0, 8 - categories.count)
            ForEach(0..<placeholderCount, id: \.self) { _ in
                PlaceholderCategoryButton(onAddCategory: onAddCategory)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Placeholder Category Button
struct PlaceholderCategoryButton: View {
    let onAddCategory: () -> Void

    var body: some View {
        Button(action: onAddCategory) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            )
        }
        .buttonStyle(.plain)
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
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .changeEffect(.wiggle, value: isSelected)
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

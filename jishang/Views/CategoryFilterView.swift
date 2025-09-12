//
//  CategoryFilterView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI
import Pow

enum MainFilterType: String, CaseIterable {
    case all = "全部"
    case income = "收入"
    case expense = "支出"
}

struct CategoryFilterView: View {
    @ObservedObject var store: TransactionStore
    @Binding var selectedFilter: FilterType
    
    @State private var isExpanded = false
    @State private var selectedMainType: MainFilterType = .all
    @State private var lastSelectedFilter: FilterType = .all
    @State private var selectedYear: Int
    @State private var selectedMonth: Int = 0 // 0 表示全年
    @Namespace private var mainButtonNamespace
    @Namespace private var subButtonNamespace
    
    init(store: TransactionStore, selectedFilter: Binding<FilterType>) {
        self.store = store
        self._selectedFilter = selectedFilter
        
        // 初始化年份和月份为当前年月
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let availableYears = store.availableYears
        
        // 优先使用当前年份，如果数据中没有当前年份则使用最新的年份
        let initialYear = availableYears.contains(currentYear) ? currentYear : (availableYears.first ?? currentYear)
        self._selectedYear = State(initialValue: initialYear)
        
        // 检查选中年份中是否包含当前月份，如果包含则默认选中当月，否则选择该年份的最新月份
        let availableMonths = store.availableMonths(for: initialYear)
        let initialMonth: Int
        if initialYear == currentYear && availableMonths.contains(currentMonth) {
            initialMonth = currentMonth  // 使用当前月份
        } else {
            initialMonth = availableMonths.last ?? 0  // 使用该年份最新的月份，如果没有则使用全年
        }
        self._selectedMonth = State(initialValue: initialMonth)
    }
    
    private var mainFilters: [FilterType] {
        return [
            .all,
            .byTransactionType(.income),
            .byTransactionType(.expense)
        ]
    }
    
    private var subcategoryFilters: [FilterType] {
        switch selectedMainType {
        case .all:
            return []
        case .income:
            return store.allCategories.filter { $0.defaultType == .income }
                .map { .byCategory($0) }
        case .expense:
            return store.allCategories.filter { $0.defaultType == .expense }
                .map { .byCategory($0) }
        }
    }
    
    private var canExpand: Bool {
        return selectedMainType != .all && !subcategoryFilters.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 第一行：主要筛选类型
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MainFilterType.allCases, id: \.self) { mainType in
                            MainFilterButton(
                                title: mainType.rawValue,
                                isSelected: selectedMainType == mainType,
                                namespace: mainButtonNamespace
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    handleMainTypeSelection(mainType)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 年份和月份选择器
                HStack(spacing: 8) {
                    // 年份Picker
                    Menu {
                        ForEach(store.availableYears, id: \.self) { year in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedYear = year
                                    selectedMonth = 0 // 重置月份为全年
                                    updateFilterForDateChange()
                                }
                            }) {
                                HStack {
                                    Text("\(String(format: "%d", year))年")
                                    if selectedYear == year {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(String(format: "%d", selectedYear))年")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // 月份Picker
                    Menu {
                        // 全年选项放在第一个
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMonth = 0
                                updateFilterForDateChange()
                            }
                        }) {
                            HStack {
                                Text("全年")
                                if selectedMonth == 0 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        // 分隔线
                        Divider()
                        
                        // 具体月份选项
                        ForEach(store.availableMonths(for: selectedYear), id: \.self) { month in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMonth = month
                                    updateFilterForDateChange()
                                }
                            }) {
                                HStack {
                                    Text("\(month)月")
                                    if selectedMonth == month {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedMonth == 0 ? "全年" : "\(selectedMonth)月")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding(.trailing)
            }
            
            // 第二行：子类别筛选（通过点击主类型自动展开/收起）
            if isExpanded && canExpand {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(subcategoryFilters.enumerated()), id: \.offset) { index, filter in
                            SubFilterButton(
                                title: filter.displayName,
                                isSelected: isSubFilterSelected(filter),
                                namespace: subButtonNamespace
                            ) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    handleSubFilterSelection(filter)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .padding(.vertical, 8)
        .onChange(of: selectedFilter) { newFilter in
            // 防止重复触发
            if newFilter != lastSelectedFilter {
                lastSelectedFilter = newFilter
                updateMainTypeFromFilter(newFilter)
            }
        }
        .onAppear {
            lastSelectedFilter = selectedFilter
            updateMainTypeFromFilter(selectedFilter)
        }
    }
    
    private func handleMainTypeSelection(_ mainType: MainFilterType) {
        // 如果已选中相同类型，则取消选中回到全部状态
        if selectedMainType == mainType && mainType != .all {
            selectedMainType = .all
            // 回到全部状态，但保持当前的日期筛选
            updateFilterForDateChange()
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
            return
        }
        
        selectedMainType = mainType
        
        // 根据主类型和当前日期筛选来更新过滤器
        updateFilterForDateChange()
        
        // 如果选择收入或支出，且有子类别，自动展开
        if canExpand && !isExpanded {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = true
            }
        } else if mainType == .all {
            isExpanded = false
        }
    }
    
    private func handleSubFilterSelection(_ filter: FilterType) {
        if let category = extractCategoryFromFilter(filter) {
            // 检查是否已经选中了这个类别（考虑日期筛选）
            let isCurrentlySelected = checkIfCategoryIsSelected(category)
            
            if isCurrentlySelected {
                // 如果已选中，则取消选中，回到主类型筛选（保持日期筛选）
                updateFilterForDateChange()
            } else {
                // 如果未选中，则选中这个类别（结合当前日期筛选）
                if selectedMonth == 0 {
                    selectedFilter = .byYearAndCategory(selectedYear, category)
                } else {
                    selectedFilter = .byMonthAndCategory(selectedYear, selectedMonth, category)
                }
            }
        }
    }
    
    private func extractCategoryFromFilter(_ filter: FilterType) -> Category? {
        switch filter {
        case .byCategory(let category):
            return category
        default:
            return nil
        }
    }
    
    private func checkIfCategoryIsSelected(_ category: Category) -> Bool {
        switch selectedFilter {
        case .byYearAndCategory(_, let selectedCategory), .byMonthAndCategory(_, _, let selectedCategory):
            return selectedCategory == category
        case .byCategory(let selectedCategory):
            return selectedCategory == category
        default:
            return false
        }
    }
    
    private func isSubFilterSelected(_ filter: FilterType) -> Bool {
        if let category = extractCategoryFromFilter(filter) {
            return checkIfCategoryIsSelected(category)
        }
        return selectedFilter == filter
    }
    
    private func updateMainTypeFromFilter(_ filter: FilterType) {
        switch filter {
        case .all:
            selectedMainType = .all
            isExpanded = false
        case .byTransactionType(let type):
            selectedMainType = type == .income ? .income : .expense
        case .byCategory(let category):
            selectedMainType = category.defaultType == .income ? .income : .expense
            if canExpand && !isExpanded {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded = true
                }
            }
        case .byYear, .byMonth, .byYearAndTransactionType, .byMonthAndTransactionType, .byYearAndCategory, .byMonthAndCategory:
            // 对于日期相关的筛选，从筛选器中提取主类型信息
            extractMainTypeFromDateFilter(filter)
        }
    }
    
    private func extractMainTypeFromDateFilter(_ filter: FilterType) {
        switch filter {
        case .byYear(let year):
            selectedYear = year
            selectedMonth = 0
            selectedMainType = .all
        case .byMonth(let year, let month):
            selectedYear = year
            selectedMonth = month
            selectedMainType = .all
        case .byYearAndTransactionType(let year, let type):
            selectedYear = year
            selectedMonth = 0
            selectedMainType = type == .income ? .income : .expense
        case .byMonthAndTransactionType(let year, let month, let type):
            selectedYear = year
            selectedMonth = month
            selectedMainType = type == .income ? .income : .expense
        case .byYearAndCategory(let year, let category):
            selectedYear = year
            selectedMonth = 0
            selectedMainType = category.defaultType == .income ? .income : .expense
        case .byMonthAndCategory(let year, let month, let category):
            selectedYear = year
            selectedMonth = month
            selectedMainType = category.defaultType == .income ? .income : .expense
        default:
            selectedMainType = .all
        }
    }
    
    private func updateFilterForDateChange() {
        // 根据当前选择的主类型、年份、月份来构建新的筛选器
        let baseFilter: FilterType
        
        if selectedMonth == 0 {
            // 全年数据
            baseFilter = .byYear(selectedYear)
        } else {
            // 特定月份数据
            baseFilter = .byMonth(selectedYear, selectedMonth)
        }
        
        // 根据当前的主类型选择，组合日期筛选
        switch selectedMainType {
        case .all:
            selectedFilter = baseFilter
        case .income:
            if selectedMonth == 0 {
                selectedFilter = .byYearAndTransactionType(selectedYear, .income)
            } else {
                selectedFilter = .byMonthAndTransactionType(selectedYear, selectedMonth, .income)
            }
        case .expense:
            if selectedMonth == 0 {
                selectedFilter = .byYearAndTransactionType(selectedYear, .expense)
            } else {
                selectedFilter = .byMonthAndTransactionType(selectedYear, selectedMonth, .expense)
            }
        }
    }
}

struct MainFilterButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.primary)
                                .matchedGeometryEffect(id: "mainBackground", in: namespace)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                        }
                    }
                )
        }
        .changeEffect(.shine, value: isSelected)
    }
}

struct SubFilterButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemFill.withAlphaComponent(0.8)))
                                .matchedGeometryEffect(id: "subBackground", in: namespace)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                        }
                    }
                )
        }
        .changeEffect(.shine, value: isSelected)
    }
}

#Preview {
    CategoryFilterView(store: TransactionStore(), selectedFilter: .constant(.all))
}

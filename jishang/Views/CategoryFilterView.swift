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
    @State private var selectedDate: Date
    @State private var selectedMonth: Int = 0 // 0 表示全年，非0表示具体月份
    @State private var selectedDay: Int = 0 // 0 表示整月，非0表示具体日期
    @Namespace private var mainButtonNamespace
    @Namespace private var subButtonNamespace
    
    init(store: TransactionStore, selectedFilter: Binding<FilterType>) {
        self.store = store
        self._selectedFilter = selectedFilter

        // 使用当前日期作为默认值，延迟到onAppear时进行数据初始化
        let now = Date()
        self._selectedDate = State(initialValue: now)
        self._selectedMonth = State(initialValue: Calendar.current.component(.month, from: now))
        self._selectedDay = State(initialValue: 0) // 默认显示整月
    }

    // 从selectedDate获取年份
    private var selectedYear: Int {
        Calendar.current.component(.year, from: selectedDate)
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
                
                // 日期选择器 (交换位置：月份在前，年份在后)
                HStack(spacing: 8) {
                    // 月份Picker (移到前面)
                    Menu {
                        // 全年选项放在第一个
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMonth = 0
                                selectedDay = 0 // 重置日期选择
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
                                    selectedDay = 0 // 重置为整月
                                    // 同时更新selectedDate以保持一致性
                                    let calendar = Calendar.current
                                    let components = DateComponents(year: selectedYear, month: month)
                                    if let newDate = calendar.date(from: components) {
                                        selectedDate = newDate
                                    }
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

                    // Daily Picker (移到后面)
                    Menu {
                        // 整月选项放在第一个
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDay = 0
                                updateFilterForDateChange()
                            }
                        }) {
                            HStack {
                                Text("整月")
                                if selectedDay == 0 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        // 分隔线
                        if !store.availableDays(for: selectedYear, month: selectedMonth).isEmpty {
                            Divider()
                        }

                        // 具体日期选项
                        ForEach(store.availableDays(for: selectedYear, month: selectedMonth), id: \.self) { day in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDay = day
                                    // 同时更新selectedDate以保持一致性
                                    let calendar = Calendar.current
                                    let components = DateComponents(year: selectedYear, month: selectedMonth, day: day)
                                    if let newDate = calendar.date(from: components) {
                                        selectedDate = newDate
                                    }
                                    updateFilterForDateChange()
                                }
                            }) {
                                HStack {
                                    Text("\(day)日")
                                    if selectedDay == day {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if selectedDay == 0 {
                                Text("整月")
                            } else {
                                Text("\(selectedDay)日")
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .disabled(selectedMonth == 0) // 如果选择了全年，则禁用日期选择
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
            // 初始化日期选择为合适的值
            initializeDateSelection()
            lastSelectedFilter = selectedFilter
            updateMainTypeFromFilter(selectedFilter)
        }
    }

    private func initializeDateSelection() {
        // 初始化日期为当前年月
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let availableYears = store.availableYears

        // 优先使用当前年份，如果数据中没有当前年份则使用最新的年份
        let initialYear = availableYears.contains(currentYear) ? currentYear : (availableYears.first ?? currentYear)

        // 检查选中年份中是否包含当前月份，如果包含则默认选中当月，否则选择该年份的最新月份
        let availableMonths = store.availableMonths(for: initialYear)
        let initialMonth: Int
        if initialYear == currentYear && availableMonths.contains(currentMonth) {
            initialMonth = currentMonth  // 使用当前月份
        } else {
            initialMonth = availableMonths.last ?? 0  // 使用该年份最新的月份，如果没有则使用全年
        }

        // 创建初始日期
        let dateComponents = DateComponents(year: initialYear, month: max(1, initialMonth))
        let initialDate = calendar.date(from: dateComponents) ?? now
        selectedDate = initialDate
        selectedMonth = initialMonth
        selectedDay = 0 // 默认显示整月
    }

    private func handleMainTypeSelection(_ mainType: MainFilterType) {
        print("[FILTER-BUTTON-CLICK] MainType button clicked: '\(mainType.rawValue)' (from '\(selectedMainType.rawValue)' to '\(mainType.rawValue)')")

        // 如果已选中相同类型，则取消选中回到全部状态
        if selectedMainType == mainType && mainType != .all {
            selectedMainType = .all
            print("[FILTER-BUTTON-CLICK] Same MainType clicked - resetting to 'all'")
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
            print("[FILTER-BUTTON-CLICK] Auto-expanding sub-filters for '\(mainType.rawValue)'")
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
                } else if selectedDay == 0 {
                    selectedFilter = .byMonthAndCategory(selectedYear, selectedMonth, category)
                } else {
                    selectedFilter = .byDayAndCategory(selectedYear, selectedMonth, selectedDay, category)
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
        case .byYearAndCategory(_, let selectedCategory),
             .byMonthAndCategory(_, _, let selectedCategory),
             .byDayAndCategory(_, _, _, let selectedCategory):
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
        case .byYear, .byMonth, .byDay, .byYearAndTransactionType, .byMonthAndTransactionType, .byDayAndTransactionType, .byYearAndCategory, .byMonthAndCategory, .byDayAndCategory:
            // 对于日期相关的筛选，从筛选器中提取主类型信息
            extractMainTypeFromDateFilter(filter)
        }
    }
    
    private func extractMainTypeFromDateFilter(_ filter: FilterType) {
        let calendar = Calendar.current

        switch filter {
        case .byYear(let year):
            let components = DateComponents(year: year, month: 1)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = 0
            selectedMainType = .all
        case .byMonth(let year, let month):
            let components = DateComponents(year: year, month: month)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = month
            selectedDay = 0
            selectedMainType = .all
        case .byDay(let year, let month, let day):
            let components = DateComponents(year: year, month: month, day: day)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = month
            selectedDay = day
            selectedMainType = .all
        case .byYearAndTransactionType(let year, let type):
            let components = DateComponents(year: year, month: 1)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = 0
            selectedDay = 0
            selectedMainType = type == .income ? .income : .expense
        case .byMonthAndTransactionType(let year, let month, let type):
            let components = DateComponents(year: year, month: month)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = month
            selectedDay = 0
            selectedMainType = type == .income ? .income : .expense
        case .byDayAndTransactionType(let year, let month, let day, let type):
            let components = DateComponents(year: year, month: month, day: day)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = month
            selectedDay = day
            selectedMainType = type == .income ? .income : .expense
        case .byYearAndCategory(let year, let category):
            let components = DateComponents(year: year, month: 1)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = 0
            selectedDay = 0
            selectedMainType = category.defaultType == .income ? .income : .expense
        case .byMonthAndCategory(let year, let month, let category):
            let components = DateComponents(year: year, month: month)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = month
            selectedDay = 0
            selectedMainType = category.defaultType == .income ? .income : .expense
        case .byDayAndCategory(let year, let month, let day, let category):
            let components = DateComponents(year: year, month: month, day: day)
            selectedDate = calendar.date(from: components) ?? selectedDate
            selectedMonth = month
            selectedDay = day
            selectedMainType = category.defaultType == .income ? .income : .expense
        default:
            selectedMainType = .all
        }
    }
    
    private func updateFilterForDateChange() {
        // 根据当前选择的主类型、年份、月份、日期来构建新的筛选器
        let baseFilter: FilterType

        if selectedMonth == 0 {
            // 全年数据
            baseFilter = .byYear(selectedYear)
        } else if selectedDay == 0 {
            // 特定月份数据
            baseFilter = .byMonth(selectedYear, selectedMonth)
        } else {
            // 特定日期数据
            baseFilter = .byDay(selectedYear, selectedMonth, selectedDay)
        }

        // 根据当前的主类型选择，组合日期筛选
        switch selectedMainType {
        case .all:
            selectedFilter = baseFilter
        case .income:
            if selectedMonth == 0 {
                selectedFilter = .byYearAndTransactionType(selectedYear, .income)
            } else if selectedDay == 0 {
                selectedFilter = .byMonthAndTransactionType(selectedYear, selectedMonth, .income)
            } else {
                selectedFilter = .byDayAndTransactionType(selectedYear, selectedMonth, selectedDay, .income)
            }
        case .expense:
            if selectedMonth == 0 {
                selectedFilter = .byYearAndTransactionType(selectedYear, .expense)
            } else if selectedDay == 0 {
                selectedFilter = .byMonthAndTransactionType(selectedYear, selectedMonth, .expense)
            } else {
                selectedFilter = .byDayAndTransactionType(selectedYear, selectedMonth, selectedDay, .expense)
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

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
    @Namespace private var mainButtonNamespace
    @Namespace private var subButtonNamespace
    
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
            return store.allCategories.filter { $0.defaultType == .income || $0.isCustom }
                .map { .byCategory($0) }
        case .expense:
            return store.allCategories.filter { $0.defaultType == .expense || $0.isCustom }
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
                
                // 展开按钮
                if canExpand {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
            }
            
            // 第二行：子类别筛选（可展开）
            if isExpanded && canExpand {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(subcategoryFilters.enumerated()), id: \.offset) { index, filter in
                            SubFilterButton(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter,
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
            selectedFilter = .all
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
            return
        }
        
        selectedMainType = mainType
        
        // 自动选择对应的FilterType
        switch mainType {
        case .all:
            selectedFilter = .all
            isExpanded = false
        case .income:
            selectedFilter = .byTransactionType(.income)
        case .expense:
            selectedFilter = .byTransactionType(.expense)
        }
        
        // 如果选择收入或支出，且有子类别，自动展开
        if canExpand && !isExpanded {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = true
            }
        }
    }
    
    private func handleSubFilterSelection(_ filter: FilterType) {
        if selectedFilter == filter {
            // 如果已选中，则取消选中，回到主类型筛选
            switch selectedMainType {
            case .income:
                selectedFilter = .byTransactionType(.income)
            case .expense:
                selectedFilter = .byTransactionType(.expense)
            case .all:
                selectedFilter = .all
            }
        } else {
            // 如果未选中，则选中这个filter
            selectedFilter = filter
        }
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
        .changeEffect(.wiggle, value: isSelected)
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
        .changeEffect(.wiggle, value: isSelected)
    }
}

#Preview {
    CategoryFilterView(store: TransactionStore(), selectedFilter: .constant(.all))
}

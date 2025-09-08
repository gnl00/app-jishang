//
//  CategoryFilterView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

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
                                isSelected: selectedMainType == mainType
                            ) {
                                handleMainTypeSelection(mainType)
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
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
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
            updateMainTypeFromFilter(newFilter)
        }
        .onAppear {
            updateMainTypeFromFilter(selectedFilter)
        }
    }
    
    private func handleMainTypeSelection(_ mainType: MainFilterType) {
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.primary : Color(.systemGray6))
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct SubFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color(UIColor.systemFill.withAlphaComponent(0.8)) : Color(.systemGray5))
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    CategoryFilterView(store: TransactionStore(), selectedFilter: .constant(.all))
}

//
//  CategoryFilterView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct CategoryFilterView: View {
    @ObservedObject var store: TransactionStore
    @Binding var selectedFilter: FilterType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(store.allFilters.enumerated()), id: \.offset) { index, filter in
                    FilterButton(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct FilterButton: View {
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
                        .fill(isSelected ? Color.brown : Color(.systemGray6))
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    CategoryFilterView(store: TransactionStore(), selectedFilter: .constant(.all))
}

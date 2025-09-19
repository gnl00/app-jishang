//
//  StatsSectionCard.swift
//  jishang
//
//  Shared container style for statistics sections
//

import SwiftUI

struct StatsSectionCard<Content: View>: View {
    let content: Content
    var innerHorizontal: CGFloat = 20
    var innerVertical: CGFloat = 16
    var outerHorizontal: CGFloat = 20

    init(innerHorizontal: CGFloat = 20,
         innerVertical: CGFloat = 16,
         outerHorizontal: CGFloat = 20,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.innerHorizontal = innerHorizontal
        self.innerVertical = innerVertical
        self.outerHorizontal = outerHorizontal
    }

    var body: some View {
        content
            .padding(.horizontal, innerHorizontal)
            .padding(.vertical, innerVertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray6), lineWidth: 1)
                    )
            )
            .padding(.horizontal, outerHorizontal)
    }
}


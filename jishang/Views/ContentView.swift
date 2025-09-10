//
//  ContentView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environmentObject(TransactionStore())
}

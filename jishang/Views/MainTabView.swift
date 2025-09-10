//
//  MainTabView.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

enum TabSelection: Int, CaseIterable {
    case home = 0
    case statistics = 1
    case settings = 2
    
    var title: String {
        switch self {
        case .home: return "首页"
        case .statistics: return "统计"
        case .settings: return "设置"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .statistics: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    
    var body: some View {
        TabView {
            HomeView()
                .environmentObject(transactionStore)
                .tabItem {
                    Image(systemName: TabSelection.home.icon)
                    Text(TabSelection.home.title)
                }
                .tag(TabSelection.home.rawValue)
            
            StatisticsView()
                .environmentObject(transactionStore)
                .tabItem {
                    Image(systemName: TabSelection.statistics.icon)
                    Text(TabSelection.statistics.title)
                }
                .tag(TabSelection.statistics.rawValue)
            
            SettingsView()
                .tabItem {
                    Image(systemName: TabSelection.settings.icon)
                    Text(TabSelection.settings.title)
                }
                .tag(TabSelection.settings.rawValue)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(TransactionStore())
}
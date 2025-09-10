//
//  JiShangApp.swift
//  jishang
//
//  Created by Gnl on 2025/9/8.
//

import SwiftUI

@main
struct JiShangApp: App {
    @StateObject private var transactionStore = TransactionStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transactionStore)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // 应用进入后台时保存数据
                    transactionStore.saveAllData()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // 应用终止时保存数据
                    transactionStore.saveAllData()
                }
        }
    }
}

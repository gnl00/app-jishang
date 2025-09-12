//
//  Calendar+Extensions.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - Calendar utility extensions for date operations
//

import Foundation

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        let startOfMonth = self.startOfMonth(for: date)
        let nextMonth = self.date(byAdding: .month, value: 1, to: startOfMonth) ?? date
        return self.date(byAdding: .day, value: -1, to: nextMonth) ?? date
    }
}
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

    /// 获取给定日期所在周的起始日（遵守当前日历的 firstWeekday），返回当天 00:00
    func startOfWeek(for date: Date) -> Date {
        let startOfDayDate = startOfDay(for: date)
        let weekday = component(.weekday, from: startOfDayDate)
        // 距离本周起始日的偏移（0...6）
        let diff = (weekday - firstWeekday + 7) % 7
        return self.date(byAdding: .day, value: -diff, to: startOfDayDate) ?? startOfDayDate
    }

    /// 获取给定日期所在周的结束日（起始日 + 6 天），返回当天 00:00（配合 UI 通常不需要到 23:59）
    func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return self.date(byAdding: .day, value: 6, to: start) ?? start
    }
}

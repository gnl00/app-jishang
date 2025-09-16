//
//  DateFormatter+Extensions.swift
//  jishang
//
//  Created by Gnl on 2025/9/12.
//  
//  Contains:
//  - Common date formatters used across the app
//

import Foundation

extension DateFormatter {
    /// 格式：yyyy年MM月 (例：2025年09月)
    static let yearMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter
    }()
    
    /// 格式：d
    static let onlyDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    /// 格式：M/d (例：9/12)
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
    
    /// 格式：M月d日 (例：9月12日)
    static let monthDayChinese: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    /// 格式：MM/dd (例：09/12)
    static let monthDayPadded: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
}

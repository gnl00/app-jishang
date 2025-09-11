//
//  VoiceTransactionParser.swift
//  jishang
//
//  Created by Gnl on 2025/9/9.
//

import Foundation

struct ParsedTransaction {
    let amount: Double
    let category: String?
    let description: String
    let type: TransactionType
}

class VoiceTransactionParser {
    
    // 金额关键词
    private let amountKeywords = ["元", "块", "毛", "分", "角"]
    
    // 收入关键词
    private let incomeKeywords = ["收入", "赚", "得到", "获得", "工资", "奖金", "红包", "转账收到"]
    
    // 支出关键词  
    private let expenseKeywords = ["花", "花了", "买", "支出", "付", "消费", "花费", "购买", "支付", "转账"]
    
    // 常见类别关键词映射
    private let categoryKeywords: [String: String] = [
        // 餐饮
        "吃": "餐饮", "饭": "餐饮", "餐": "餐饮", "喝": "餐饮", "咖啡": "餐饮", 
        "奶茶": "餐饮", "早餐": "餐饮", "午餐": "餐饮", "晚餐": "餐饮", "夜宵": "餐饮",
        
        // 交通
        "打车": "交通", "地铁": "交通", "公交": "交通", "出租车": "交通", "滴滴": "交通", 
        "油费": "交通", "停车": "交通", "高速": "交通", "火车": "交通", "飞机": "交通",
        "充电": "交通", // 新增充电关键词，归类为交通
        
        // 购物
        "衣服": "购物", "鞋": "购物", "包": "购物", "化妆品": "购物", "护肤": "购物",
        "书": "购物", "文具": "购物", "电子": "购物", "手机": "购物", "电脑": "购物",
        
        // 娱乐
        "电影": "娱乐", "游戏": "娱乐", "KTV": "娱乐", "旅游": "娱乐", "健身": "娱乐",
        
        // 生活
        "房租": "居住", "水费": "居住", "电费": "居住", "燃气": "居住", "物业": "居住",
        "医院": "医疗", "药": "医疗", "看病": "医疗", "体检": "医疗",
        
        // 收入类别
        "工资": "工资", "奖金": "奖金", "红包": "红包", "兼职": "兼职", "投资": "投资"
    ]
    
    func parseVoiceText(_ text: String, expectedType: TransactionType) -> ParsedTransaction? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return nil }
        
        // 解析金额
        guard let amount = extractAmount(from: cleanText) else { return nil }
        
        // 推断交易类型
        let inferredType = inferTransactionType(from: cleanText, expected: expectedType)
        
        // 提取类别
        let category = extractCategory(from: cleanText, type: inferredType)
        
        // 生成描述
        let description = generateDescription(from: cleanText, amount: amount, category: category)
        
        return ParsedTransaction(
            amount: amount,
            category: category,
            description: description,
            type: inferredType
        )
    }
    
    private func extractAmount(from text: String) -> Double? {
        // 使用正则表达式匹配数字+金额单位，支持逗号分隔的数字
        let patterns = [
            "([0-9,]+\\.?[0-9]*)\\s*元",
            "([0-9,]+\\.?[0-9]*)\\s*块\\s*钱?", // 支持"块钱"组合
            "([0-9,]+\\.?[0-9]*)\\s*块", 
            "([0-9,]+\\.?[0-9]*)\\s*毛",
            "([0-9,]+)\\s*分",
            "([0-9,]+\\.?[0-9]*)"  // 纯数字，作为兜底
        ]
        
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let matchString = String(text[range])
                // 移除所有非数字和小数点的字符，包括逗号
                let numberString = matchString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                if let amount = Double(numberString) {
                    // 根据单位调整金额
                    if matchString.contains("分") {
                        return amount / 100
                    } else if matchString.contains("毛") || matchString.contains("角") {
                        return amount / 10
                    }
                    return amount
                }
            }
        }
        
        return nil
    }
    
    private func inferTransactionType(from text: String, expected: TransactionType) -> TransactionType {
        let lowercaseText = text.lowercased()
        
        // 检查是否包含明确的收入关键词
        for keyword in incomeKeywords {
            if lowercaseText.contains(keyword) {
                return .income
            }
        }
        
        // 检查是否包含明确的支出关键词
        for keyword in expenseKeywords {
            if lowercaseText.contains(keyword) {
                return .expense
            }
        }
        
        // 如果没有明确关键词，使用期望的类型
        return expected
    }
    
    private func extractCategory(from text: String, type: TransactionType) -> String? {
        for (keyword, category) in categoryKeywords {
            if text.contains(keyword) {
                return category
            }
        }
        return nil
    }
    
    private func generateDescription(from text: String, amount: Double, category: String?) -> String {
        // 移除金额部分
        var description = text
        let amountPatterns = [
            "[0-9,]+\\.?[0-9]*\\s*元",
            "[0-9,]+\\.?[0-9]*\\s*块\\s*钱?", // 支持"块钱"组合
            "[0-9,]+\\.?[0-9]*\\s*块",
            "[0-9,]+\\.?[0-9]*\\s*毛", 
            "[0-9,]+\\s*分",
            "[0-9,]+\\.?[0-9]*"  // 纯数字也要移除
        ]
        
        for pattern in amountPatterns {
            description = description.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 清理多余的空格和标点
        description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        description = description.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 如果描述为空或过短，生成默认描述
        if description.isEmpty || description.count < 2 {
            if let category = category {
                return "\(category)消费"
            } else {
                return "语音记录"
            }
        }
        
        return description
    }
}

// 使用示例扩展
extension VoiceTransactionParser {
    static func parseExamples() {
        let parser = VoiceTransactionParser()
        
        let examples = [
            "午饭花了30元",
            "买咖啡15块5", 
            "打车到公司25元",
            "工资收入5000元",
            "工资收入50,000元",  // 测试逗号分隔的数字
            "红包收到200块",
            "电影票60元",
            "房租2500元",
            "打车花了12.73元",        // 测试小数
            "工资收入 10563.82 元",    // 测试带空格的小数
            "充电花了5块钱"           // 测试充电场景
        ]
        
        for example in examples {
            if let result = parser.parseVoiceText(example, expectedType: .expense) {
                print("输入: \(example)")
                print("金额: \(result.amount), 类别: \(result.category ?? "无"), 描述: \(result.description), 类型: \(result.type)")
                print("---")
            }
        }
    }
}

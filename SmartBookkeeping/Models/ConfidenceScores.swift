//
//  ConfidenceScores.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation

/// 置信度分数结构体，用于表示AI识别结果的置信度
struct ConfidenceScores {
    var amount: Double = ConfidenceConfig.Defaults.amount
    var category: Double = ConfidenceConfig.Defaults.category
    var account: Double = ConfidenceConfig.Defaults.account
    var description: Double = ConfidenceConfig.Defaults.description
    var date: Double = ConfidenceConfig.Defaults.date
    var notes: Double = ConfidenceConfig.Defaults.notes
    
    /// 初始化方法
    init() {}
    
    /// 自定义初始化方法
    init(amount: Double = ConfidenceConfig.Defaults.amount,
         category: Double = ConfidenceConfig.Defaults.category,
         account: Double = ConfidenceConfig.Defaults.account,
         description: Double = ConfidenceConfig.Defaults.description,
         date: Double = ConfidenceConfig.Defaults.date,
         notes: Double = ConfidenceConfig.Defaults.notes) {
        self.amount = amount
        self.category = category
        self.account = account
        self.description = description
        self.date = date
        self.notes = notes
    }
    
    /// 获取所有置信度的平均值
    var averageConfidence: Double {
        return (amount + category + account + description + date + notes) / 6.0
    }
    
    /// 获取低置信度字段的数量
    var lowConfidenceCount: Int {
        let threshold = ConfidenceConfig.lowConfidenceThreshold
        var count = 0
        if amount < threshold { count += 1 }
        if category < threshold { count += 1 }
        if account < threshold { count += 1 }
        if description < threshold { count += 1 }
        if date < threshold { count += 1 }
        if notes < threshold { count += 1 }
        return count
    }
    
    /// 检查是否有任何字段的置信度低于阈值
    var hasLowConfidence: Bool {
        return lowConfidenceCount > 0
    }
    
    /// 获取置信度详细描述
    var detailedDescription: String {
        return """
        Confidence Scores:
        - Amount: \(String(format: "%.2f", amount))
        - Category: \(String(format: "%.2f", category))
        - Account: \(String(format: "%.2f", account))
        - Description: \(String(format: "%.2f", description))
        - Date: \(String(format: "%.2f", date))
        - Notes: \(String(format: "%.2f", notes))
        - Average: \(String(format: "%.2f", averageConfidence))
        - Low Confidence Fields: \(lowConfidenceCount)
        """
    }
}

// MARK: - Codable 支持

extension ConfidenceScores: Codable {
    enum CodingKeys: String, CodingKey {
        case amount, category, account, description, date, notes
    }
}

// MARK: - Equatable 支持

extension ConfidenceScores: Equatable {
    static func == (lhs: ConfidenceScores, rhs: ConfidenceScores) -> Bool {
        return abs(lhs.amount - rhs.amount) < 0.001 &&
               abs(lhs.category - rhs.category) < 0.001 &&
               abs(lhs.account - rhs.account) < 0.001 &&
               abs(lhs.description - rhs.description) < 0.001 &&
               abs(lhs.date - rhs.date) < 0.001 &&
               abs(lhs.notes - rhs.notes) < 0.001
    }
}
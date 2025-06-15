//
//  ConfidenceLearningService.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation

/// 置信度学习服务，用于根据用户反馈优化置信度预测
class ConfidenceLearningService {
    static let shared = ConfidenceLearningService()
    
    private let userDefaults = UserDefaults.standard
    private let feedbackKey = "confidence_feedback_data"
    
    // 用户反馈数据结构
    struct UserFeedback: Codable {
        let field: String
        let originalValue: String
        let correctedValue: String?
        let wasCorrect: Bool
        let originalConfidence: Double
        let timestamp: Date
    }
    
    private init() {}
    
    /// 记录用户反馈
    /// - Parameters:
    ///   - field: 字段名称（如 "amount", "category", "account" 等）
    ///   - originalValue: AI 识别的原始值
    ///   - correctedValue: 用户修正后的值（如果有）
    ///   - wasCorrect: AI 识别是否正确
    ///   - originalConfidence: 原始置信度
    func recordUserFeedback(
        field: String,
        originalValue: String,
        correctedValue: String?,
        wasCorrect: Bool,
        originalConfidence: Double
    ) {
        let feedback = UserFeedback(
            field: field,
            originalValue: originalValue,
            correctedValue: correctedValue,
            wasCorrect: wasCorrect,
            originalConfidence: originalConfidence,
            timestamp: Date()
        )
        
        var feedbackHistory = getFeedbackHistory()
        feedbackHistory.append(feedback)
        
        // 保持最近 1000 条记录
        if feedbackHistory.count > 1000 {
            feedbackHistory = Array(feedbackHistory.suffix(1000))
        }
        
        saveFeedbackHistory(feedbackHistory)
        
        print("DEBUG: ConfidenceLearningService - Recorded feedback for \(field): wasCorrect=\(wasCorrect), confidence=\(originalConfidence)")
    }
    
    /// 获取字段的建议置信度
    /// - Parameters:
    ///   - field: 字段名称
    ///   - value: 识别的值
    /// - Returns: 建议的置信度
    func getSuggestedConfidence(for field: String, value: String?) -> Double {
        let feedbackHistory = getFeedbackHistory()
        let fieldFeedback = feedbackHistory.filter { $0.field == field }
        
        guard !fieldFeedback.isEmpty else {
            // 没有历史数据，使用默认值
            return getDefaultConfidence(for: field)
        }
        
        // 计算该字段的平均准确率
        let correctCount = fieldFeedback.filter { $0.wasCorrect }.count
        let totalCount = fieldFeedback.count
        let accuracyRate = Double(correctCount) / Double(totalCount)
        
        // 根据准确率调整置信度
        let baseConfidence = getDefaultConfidence(for: field)
        let adjustedConfidence = baseConfidence * (0.5 + accuracyRate * 0.5)
        
        // 特殊情况处理
        if let value = value {
            // 如果值为空或默认值，降低置信度
            if value.isEmpty || isDefaultValue(value, for: field) {
                return max(0.1, adjustedConfidence * 0.5)
            }
        }
        
        return min(0.95, max(0.1, adjustedConfidence))
    }
    
    /// 获取字段的准确率统计
    /// - Parameter field: 字段名称
    /// - Returns: 准确率（0.0-1.0）
    func getAccuracyRate(for field: String) -> Double {
        let feedbackHistory = getFeedbackHistory()
        let fieldFeedback = feedbackHistory.filter { $0.field == field }
        
        guard !fieldFeedback.isEmpty else { return 0.0 }
        
        let correctCount = fieldFeedback.filter { $0.wasCorrect }.count
        return Double(correctCount) / Double(fieldFeedback.count)
    }
    
    /// 清除反馈历史
    func clearFeedbackHistory() {
        userDefaults.removeObject(forKey: feedbackKey)
        print("DEBUG: ConfidenceLearningService - Cleared feedback history")
    }
    
    // MARK: - 私有方法
    
    private func getFeedbackHistory() -> [UserFeedback] {
        guard let data = userDefaults.data(forKey: feedbackKey),
              let feedback = try? JSONDecoder().decode([UserFeedback].self, from: data) else {
            return []
        }
        return feedback
    }
    
    private func saveFeedbackHistory(_ feedback: [UserFeedback]) {
        if let data = try? JSONEncoder().encode(feedback) {
            userDefaults.set(data, forKey: feedbackKey)
        }
    }
    
    private func getDefaultConfidence(for field: String) -> Double {
        switch field {
        case "amount":
            return ConfidenceConfig.Defaults.amount
        case "category":
            return ConfidenceConfig.Defaults.category
        case "account":
            return ConfidenceConfig.Defaults.account
        case "description":
            return ConfidenceConfig.Defaults.description
        case "date":
            return ConfidenceConfig.Defaults.date
        case "notes":
            return ConfidenceConfig.Defaults.notes
        default:
            return 0.5
        }
    }
    
    private func isDefaultValue(_ value: String, for field: String) -> Bool {
        switch field {
        case "category":
            return value == "未分类" || value == "其他"
        case "account":
            return value == "未知" || value == "默认账户"
        case "description":
            return value == "未识别" || value.isEmpty
        case "notes":
            return value == "无" || value.isEmpty
        default:
            return value.isEmpty
        }
    }
}
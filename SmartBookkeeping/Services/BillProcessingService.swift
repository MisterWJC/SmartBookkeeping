//
//  BillProcessingService.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import UIKit

/// 账单处理服务，负责处理 AI 服务返回的账单信息
class BillProcessingService {
    static let shared = BillProcessingService()
    
    // 使用统一的数据管理器
    private let categoryManager = CategoryDataManager.shared
    
    private init() {}
    
    /// 处理 AI 服务返回的账单信息，转换为 Transaction 对象
    /// - Parameter aiResponse: AI 服务返回的账单信息
    /// - Returns: 处理后的 Transaction 对象，如果处理失败则返回 nil
    func processAIResponse(_ aiResponse: ZhipuAIResponse?) -> Transaction? {
        guard let response = aiResponse else { return nil }
        
        // 解析交易类型
        let transactionType = determineTransactionType(from: response.transaction_type)
        
        // 解析日期
        let transactionDate = parseTransactionDate(from: response.transaction_time)
        
        // 根据交易类型选择合适的类别列表
        let categoryList = categoryManager.categories(for: transactionType)
        
        // 处理类别和支付方式，使用相似度匹配
        let category = findBestMatch(for: response.category, from: categoryList) ?? "未分类"
        let paymentMethod = findBestMatch(for: response.payment_method, from: categoryManager.paymentMethods) ?? "未知"
        
        // 创建 Transaction 对象
        return Transaction(
            amount: abs(response.amount ?? 0.0),
            date: transactionDate,
            category: category,
            description: response.item_description ?? "",
            type: transactionType,
            paymentMethod: paymentMethod,
            note: response.notes ?? ""
        )
    }
    
    /// 将 AI 响应格式化为可读文本
    /// - Parameter aiResponse: AI 服务返回的账单信息
    /// - Returns: 格式化后的文本
    func formatAIResponseToText(_ aiResponse: ZhipuAIResponse?) -> String {
        guard let response = aiResponse else { 
            return "无法识别账单信息，请重试或手动输入。" 
        }
        
        // 处理类别和支付方式，使用相似度匹配
        let transactionType = determineTransactionType(from: response.transaction_type)
        let categoryList = categoryManager.categories(for: transactionType)
        let category = findBestMatch(for: response.category, from: categoryList) ?? "未分类"
        let paymentMethod = findBestMatch(for: response.payment_method, from: categoryManager.paymentMethods) ?? "未知"
        
        return """
        金额：¥\(response.amount?.description ?? "未识别")
        时间：\(response.transaction_time ?? "未识别")
        说明：\(response.item_description ?? "未识别")
        分类：\(category)
        类型：\(transactionType.rawValue)
        支付方式：\(paymentMethod)
        备注：\(response.notes ?? "无")
        """
    }
    
    // MARK: - 辅助方法
    
    /// 根据 AI 返回的交易类型确定实际的交易类型
    /// - Parameter typeString: AI 返回的交易类型字符串
    /// - Returns: 确定的交易类型
    private func determineTransactionType(from typeString: String?) -> Transaction.TransactionType {
        guard let typeString = typeString?.lowercased() else { return .expense }
        
        if typeString.contains("收入") {
            return .income
        } else if typeString.contains("转账") {
            return .transfer
        } else {
            return .expense
        }
    }
    
    /// 解析交易日期
    /// - Parameter dateString: 日期字符串
    /// - Returns: 解析后的日期，如果解析失败则返回当前日期
    private func parseTransactionDate(from dateString: String?) -> Date {
        guard let dateString = dateString, !dateString.isEmpty else { return Date() }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // 尝试其他可能的日期格式
        let possibleFormats = [
            "yyyy年MM月dd日",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM月dd日",
            "MM-dd"
        ]
        
        for format in possibleFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        return Date()
    }
    
    /// 计算两个字符串之间的 Levenshtein 距离
    /// - Parameters:
    ///   - a: 第一个字符串
    ///   - b: 第二个字符串
    /// - Returns: Levenshtein 距离
    private func levenshteinDistance(a: String, b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        
        var dp = Array(repeating: Array(repeating: 0, count: bChars.count + 1), count: aChars.count + 1)
        
        for i in 0...aChars.count {
            dp[i][0] = i
        }
        
        for j in 0...bChars.count {
            dp[0][j] = j
        }
        
        for i in 1...aChars.count {
            for j in 1...bChars.count {
                let cost = (aChars[i-1] == bChars[j-1]) ? 0 : 1
                dp[i][j] = min(
                    dp[i-1][j] + 1,      // 删除
                    dp[i][j-1] + 1,      // 插入
                    dp[i-1][j-1] + cost  // 替换
                )
            }
        }
        
        return dp[aChars.count][bChars.count]
    }
    
    /// 使用 Jaro-Winkler 距离计算字符串相似度
    /// - Parameters:
    ///   - a: 第一个字符串
    ///   - b: 第二个字符串
    /// - Returns: 相似度，范围 0-1，1 表示完全相同
    private func jaroWinklerSimilarity(a: String, b: String) -> Double {
        // 如果字符串为空，返回 0
        if a.isEmpty && b.isEmpty { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }
        
        let aChars = Array(a)
        let bChars = Array(b)
        
        // 计算匹配窗口大小
        let matchDistance = max(0, max(aChars.count, bChars.count) / 2 - 1)
        
        // 初始化匹配标记数组
        var aMatches = Array(repeating: false, count: aChars.count)
        var bMatches = Array(repeating: false, count: bChars.count)
        
        // 计算匹配字符数
        var matchCount = 0
        for i in 0..<aChars.count {
            let start = max(0, i - matchDistance)
            let end = min(i + matchDistance + 1, bChars.count)
            
            // 确保范围有效
            guard start < end else { continue }
            
            for j in start..<end {
                if !bMatches[j] && aChars[i] == bChars[j] {
                    aMatches[i] = true
                    bMatches[j] = true
                    matchCount += 1
                    break
                }
            }
        }
        
        // 如果没有匹配，返回 0
        if matchCount == 0 { return 0.0 }
        
        // 计算转置次数
        var transpositions = 0
        var j = 0
        for i in 0..<aChars.count {
            if aMatches[i] {
                while j < bMatches.count && !bMatches[j] { j += 1 }
                if j < bMatches.count && aChars[i] != bChars[j] { transpositions += 1 }
                j += 1
            }
        }
        
        // 计算 Jaro 距离
        let m = Double(matchCount)
        let t = Double(transpositions) / 2.0
        let jaro = (m / Double(aChars.count) + m / Double(bChars.count) + (m - t) / m) / 3.0
        
        // 计算公共前缀长度
        var prefixLength = 0
        let maxPrefixLength = min(4, min(aChars.count, bChars.count))
        for i in 0..<maxPrefixLength {
            if aChars[i] == bChars[i] {
                prefixLength += 1
            } else {
                break
            }
        }
        
        // 计算 Jaro-Winkler 距离
        let p = 0.1 // 缩放因子，通常为 0.1
        return jaro + Double(prefixLength) * p * (1.0 - jaro)
    }
    
    /// 从列表中找到与输入字符串最相似的字符串
    /// - Parameters:
    ///   - input: 输入字符串
    ///   - list: 候选字符串列表
    /// - Returns: 最相似的字符串，如果没有找到则返回 nil
    private func findBestMatch(for input: String?, from list: [String]) -> String? {
        guard let input = input, !input.isEmpty, !list.isEmpty else { return nil }
        
        // 完全匹配优先
        if list.contains(input) {
            return input
        }
        
        var bestMatch: String? = nil
        var maxSimilarity = 0.0
        
        for item in list {
            // 使用 Jaro-Winkler 相似度算法
            let similarity = jaroWinklerSimilarity(a: input, b: item)
            
            // 如果找到更相似的匹配
            if similarity > maxSimilarity {
                maxSimilarity = similarity
                bestMatch = item
            }
        }
        
        // 设置相似度阈值，如果最大相似度低于阈值，则认为没有好的匹配
        if maxSimilarity < 0.6 {
            // 尝试使用 Levenshtein 距离作为备选方法
            var minDistance = Int.max
            var levenshteinBestMatch: String? = nil
            
            for item in list {
                let distance = levenshteinDistance(a: input, b: item)
                if distance < minDistance {
                    minDistance = distance
                    levenshteinBestMatch = item
                }
            }
            
            // 如果 Levenshtein 距离足够小，使用它的结果
            if let match = levenshteinBestMatch, minDistance <= (input.count / 2) + 2 {
                return match
            }
            
            // 如果两种方法都没有找到好的匹配，返回 nil
            return nil
        }
        
        return bestMatch
    }
    
    /// 包含关键词检查
    /// - Parameters:
    ///   - input: 输入字符串
    ///   - keywords: 关键词列表
    /// - Returns: 是否包含任一关键词
    private func containsAnyKeyword(_ input: String, keywords: [String]) -> Bool {
        let lowercaseInput = input.lowercased()
        return keywords.contains { lowercaseInput.contains($0.lowercased()) }
    }
}
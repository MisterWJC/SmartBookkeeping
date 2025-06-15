//
//  ValidationUtils.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2024/01/01.
//

import Foundation
import SwiftUI

struct ValidationUtils {
    
    // MARK: - 金额验证
    
    static func validateAmount(_ amountString: String) -> ValidationResult<Double> {
        guard !amountString.isEmpty else {
            return .failure("金额不能为空")
        }
        
        // 移除可能的货币符号和空格
        let cleanedString = amountString
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        guard let amount = Double(cleanedString) else {
            return .failure("请输入有效的金额")
        }
        
        guard amount > 0 else {
            return .failure("金额必须大于0")
        }
        
        guard amount <= 999999.99 else {
            return .failure("金额不能超过999,999.99")
        }
        
        // 检查小数位数
        let decimalParts = cleanedString.components(separatedBy: ".")
        if decimalParts.count > 1 && decimalParts[1].count > 2 {
            return .failure("金额最多保留两位小数")
        }
        
        return .success(amount)
    }
    
    // MARK: - 日期验证
    
    static func validateDate(_ date: Date) -> ValidationResult<Date> {
        let now = Date()
        let calendar = Calendar.current
        
        // 检查日期不能超过当前时间太多（允许1小时的误差）
        if date.timeIntervalSince(now) > 3600 {
            return .failure("交易时间不能超过当前时间")
        }
        
        // 检查日期不能太久远（不超过10年前）
        if let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: now),
           date < tenYearsAgo {
            return .failure("交易时间不能超过10年前")
        }
        
        return .success(date)
    }
    
    // MARK: - 文本验证
    
    static func validateDescription(_ description: String) -> ValidationResult<String> {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure("商品描述不能为空")
        }
        
        guard trimmed.count <= 100 else {
            return .failure("商品描述不能超过100个字符")
        }
        
        return .success(trimmed)
    }
    
    static func validateNotes(_ notes: String) -> ValidationResult<String> {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count <= 200 else {
            return .failure("备注不能超过200个字符")
        }
        
        return .success(trimmed)
    }
    
    // MARK: - 分类和账户验证
    
    static func validateCategory(_ category: String) -> ValidationResult<String> {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure("请选择交易分类")
        }
        
        return .success(trimmed)
    }
    
    static func validateAccount(_ account: String) -> ValidationResult<String> {
        let trimmed = account.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure("请选择账户")
        }
        
        return .success(trimmed)
    }
    
    // MARK: - 交易类型验证
    
    static func validateTransactionType(_ type: String) -> ValidationResult<String> {
        let validTypes = ["收入", "支出"]
        
        guard validTypes.contains(type) else {
            return .failure("无效的交易类型")
        }
        
        return .success(type)
    }
    
    // MARK: - 完整交易验证
    
    static func validateTransaction(amount: Double, category: String, account: String, description: String, date: Date) -> [String] {
        var errors: [String] = []
        
        if case .failure(let error) = validateAmount(String(amount)) {
            errors.append(error)
        }
        
        if case .failure(let error) = validateDate(date) {
            errors.append(error)
        }
        
        if case .failure(let error) = validateDescription(description) {
            errors.append(error)
        }
        
        if case .failure(let error) = validateCategory(category) {
            errors.append(error)
        }
        
        if case .failure(let error) = validateAccount(account) {
            errors.append(error)
        }
        
        return errors
    }
}

// MARK: - 验证结果枚举

enum ValidationResult<T> {
    case success(T)
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let message):
            return message
        }
    }
}

// MARK: - 格式化工具

struct FormatUtils {
    
    static func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    static func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
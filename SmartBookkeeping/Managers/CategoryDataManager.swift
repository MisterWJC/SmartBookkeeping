//
//  CategoryDataManager.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation

class CategoryDataManager {
    static let shared = CategoryDataManager()
    
    private init() {}
    
    // 支出分类
    let expenseCategories = ["数码电器", "餐饮美食", "自我提升", "服装饰品", "日用百货", "车辆交通", "娱乐休闲", "医疗健康", "家庭支出", "充值缴费", "其他", "总计"]
    
    // 收入分类
    let incomeCategories = ["副业收入", "投资理财", "主业收入", "红包礼金", "其他收入", "合计"]
    
    // 支付方式
    let paymentMethods = ["现金", "招商银行卡", "中信银行卡", "交通银行卡", "建设银行卡", "微信", "支付宝", "招商信用卡", "未知"]
    
    // 根据交易类型返回对应的分类列表
    func categories(for type: Transaction.TransactionType) -> [String] {
        switch type {
        case .expense, .transfer:
            return expenseCategories
        case .income:
            return incomeCategories
        }
    }
    
    // 返回支付方式列表
    func paymentMethods(for type: Transaction.TransactionType) -> [String] {
        return paymentMethods
    }
}
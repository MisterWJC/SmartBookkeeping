//
//  TransactionViewModel.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import SwiftUI
import Combine

class TransactionViewModel: ObservableObject {
    // 静态列表数据
    let expenseCategories = ["请选择分类", "数码电器", "餐饮美食", "自我提升", "服装饰品", "日用百货", "车辆交通", "娱乐休闲", "医疗健康", "家庭支出", "充值缴费", "其他", "总计"]
    let incomeCategories = ["请选择分类", "副业收入", "投资理财", "主业收入", "红包礼金", "合计"]
    let paymentMethods = ["请选择", "现金", "招商银行卡", "中信银行卡", "交通银行卡", "建设银行卡", "微信", "支付宝", "招商信用卡"]
    
    // 根据交易类型动态返回分类列表
    func categories(for type: Transaction.TransactionType) -> [String] {
        switch type {
        case .expense, .transfer://, .investment: // TODO:转账和投资也可能需要从支出分类中选择
            return expenseCategories
        case .income:
            return incomeCategories
        }
    }
    
    // 付款/收款方式列表（目前收入和支出场景相同）
    func paymentMethods(for type: Transaction.TransactionType) -> [String] {
        return paymentMethods // 简单返回，如果后续有不同再调整
    }
    @Published var transactions: [Transaction] = []
    @Published var currentMonthIncome: Double = 0.0
    @Published var currentMonthExpense: Double = 0.0
    
    // 当前月份的统计数据
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 监听交易数据变化，更新统计信息
        $transactions
            .sink { [weak self] transactions in
                self?.updateStatistics(with: transactions)
            }
            .store(in: &cancellables)
    }
    
    func updateStatistics(with transactions: [Transaction]) {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // 筛选当月交易
        let currentMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear
        }
        
        // 计算收入和支出
        currentMonthIncome = currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        currentMonthExpense = currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
    }
    
    func getTransactionTypeDistribution() -> [String: Double] {
        var distribution: [String: Double] = [
            "收入": 0,
            "支出": 0,
            "转账": 0,
            // "投资": 0
        ]
        
        for transaction in transactions {
            distribution[transaction.type.rawValue]? += transaction.amount
        }
        
        return distribution
    }
}

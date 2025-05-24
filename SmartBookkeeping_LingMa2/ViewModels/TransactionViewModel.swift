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
//
//  Transaction.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var amount: Double
    var date: Date
    var category: String
    var description: String
    var type: TransactionType
    var paymentMethod: String
    var note: String
    
    enum TransactionType: String, Codable, CaseIterable {
        case income = "收入"
        case expense = "支出"
    }
}
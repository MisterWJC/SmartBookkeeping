//
//  DailyTransactionListView.swift
//  SmartBookkeeping_LingMa2
//  用于显示某一天的所有交易记录。这个视图将包含日期、星期、当日总支出和总收入，以及一个交易列表（使用前面创建的 TransactionRowView ）。
//  Created by JasonWang on 2025/5/27.
//

import SwiftUI

struct DailyTransactionListView: View {
    let date: Date
    let transactions: [Transaction]

    private var dailyIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var dailyExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date, style: .date)
                    .font(.headline)
                Text(date, formatter: Self.weekdayFormatter)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("支出 ¥\(dailyExpense, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.red)
                Text("收入 ¥\(dailyIncome, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            
            if transactions.isEmpty {
                Text("当日无交易记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(transactions) { transaction in
                    TransactionRowView(transaction: transaction)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // 例如 "星期一"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

#Preview {
    let sampleTransactionsForDay1: [Transaction] = [
        Transaction(amount: 38.00, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "微信", note: ""),
        Transaction(amount: 248.00, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, category: "日用百货", description: "超市购物", type: .expense, paymentMethod: "支付宝", note: "")
    ]
    
    let sampleTransactionsForDay2: [Transaction] = [
        Transaction(amount: 12500.00, date: Date(), category: "工资收入", description: "工资收入", type: .income, paymentMethod: "银行卡", note: ""),
        Transaction(amount: 168.00, date: Date(), category: "交通出行", description: "打车", type: .expense, paymentMethod: "支付宝", note: "")
    ]
    
    return ScrollView {
        VStack {
            DailyTransactionListView(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, transactions: sampleTransactionsForDay1)
            DailyTransactionListView(date: Date(), transactions: sampleTransactionsForDay2)
        }
    }
}
//
//  FilteredTransactionView.swift
//  SmartBookkeeping
//
//  按账户筛选的交易流水视图
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct FilteredTransactionView: View {
    let accountName: String
    @EnvironmentObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    
    // 筛选后的交易记录
    private var filteredTransactions: [Transaction] {
        viewModel.transactions.filter { transaction in
            transaction.paymentMethod == accountName
        }.sorted { $0.date > $1.date }
    }
    
    // 按日期分组的交易记录
    private var groupedTransactions: [String: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: transaction.date)
        }
    }
    
    // 排序后的日期键
    private var sortedDateKeys: [String] {
        groupedTransactions.keys.sorted { $0 > $1 }
    }
    
    // 账户统计信息
    private var accountStats: (income: Double, expense: Double, balance: Double) {
        let income = filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        let expense = filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        
        return (income: income, expense: expense, balance: income - expense)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 账户统计信息
            VStack(spacing: 12) {
                Text(accountName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("收入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", accountStats.income))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    VStack {
                        Text("支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", accountStats.expense))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    VStack {
                        Text("余额")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", accountStats.balance))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(accountStats.balance >= 0 ? .primary : .red)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // 交易记录列表
            if filteredTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("该账户暂无交易记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("开始记录您的第一笔交易吧")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
            } else {
                List {
                    ForEach(sortedDateKeys, id: \.self) { dateKey in
                        Section(header: Text(formatDateHeader(dateKey))) {
                            ForEach(groupedTransactions[dateKey] ?? [], id: \.id) { transaction in
                                TransactionRowView(transaction: transaction)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("账户流水")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchTransactions()
        }
    }
    
    private func formatDateHeader(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MM月dd日 EEEE"
        outputFormatter.locale = Locale(identifier: "zh_CN")
        
        return outputFormatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        FilteredTransactionView(accountName: "招商银行")
    }
}
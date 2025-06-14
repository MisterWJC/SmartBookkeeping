//
//  TransactionRowView.swift
//  SmartBookkeeping
//  显示单条交易记录。这个视图将根据图片中的样式，包含一个图标、交易描述（如“午餐”）、交易分类（如“餐饮美食”）和交易金额。
//  Created by JasonWang on 2025/5/27.
//

import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    @State private var showingEditView = false
    @EnvironmentObject var viewModel: TransactionViewModel

    var body: some View {
        HStack {
            Image(systemName: iconName(for: transaction.category))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading) {
                Text(transaction.description)
                    .font(.headline)
                Text(transaction.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transaction.date, style: .date) // 占位，将被替换
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(String(format: "%@%.2f", transaction.type == .income ? "+" : "-", transaction.amount))
                .font(.headline)
                .foregroundColor(transaction.type == .income ? .green : .red)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            showingEditView = true
        }
        .sheet(isPresented: $showingEditView) {
            TransactionEditView(transaction: transaction, viewModel: viewModel)
        }
    }

    // 添加一个静态的 DateFormatter 用于显示日期和时间
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // 根据分类返回SF Symbol名称的辅助函数
    // TODO: 需要根据实际的分类名称完善图标映射
    private func iconName(for category: String) -> String {
        switch category.lowercased() {
        case "餐饮美食", "午餐":
            return "fork.knife"
        case "超市购物", "日用百货":
            return "cart.fill"
        case "交通出行", "打车":
            return "car.fill"
        case "工资收入":
            return "dollarsign.circle.fill"
        // 添加更多分类和对应的图标
        default:
            return "questionmark.circle.fill" // 默认图标
        }
    }
}

#Preview {
    VStack {
        TransactionRowView(transaction: Transaction(amount: 38.00, date: Date(), category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "微信", note: ""))
        TransactionRowView(transaction: Transaction(amount: 248.00, date: Date(), category: "日用百货", description: "超市购物", type: .expense, paymentMethod: "支付宝", note: ""))
        TransactionRowView(transaction: Transaction(amount: 12500.00, date: Date(), category: "工资收入", description: "工资收入", type: .income, paymentMethod: "银行卡", note: ""))
        TransactionRowView(transaction: Transaction(amount: 168.00, date: Date(), category: "交通出行", description: "打车", type: .expense, paymentMethod: "支付宝", note: ""))
    }
    .padding()
}
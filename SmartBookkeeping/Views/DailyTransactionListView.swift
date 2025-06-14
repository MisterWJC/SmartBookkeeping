//
//  DailyTransactionListView.swift
//  SmartBookkeeping
//  用于显示某一天的所有交易记录。这个视图将包含日期、星期、当日总支出和总收入，以及一个交易列表（使用前面创建的 TransactionRowView ）。
//  Created by JasonWang on 2025/5/27.
//

import SwiftUI

struct DailyTransactionListView: View {
    @EnvironmentObject var viewModel: TransactionViewModel // 注入ViewModel
    let date: Date // 代表分组的起始日期 (天、周一、月初、季度初、年初)
    let transactions: [Transaction]
    let timeRange: TransactionHistoryView.TimeRange // 传入当前选择的时间范围
    @State private var transactionToEdit: Transaction?

    private var dailyIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var dailyExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    private var dailyBalance: Double {
        dailyIncome - dailyExpense
    }



    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDateTitle(for: date, range: timeRange))
                        .font(.headline)
                    // 周视图时，可以额外显示周的起止日期，或者只显示周数
                    // 其他视图下，星期的概念可能不那么重要，或者可以省略
                    if timeRange == .day {
                        Text(date, formatter: Self.weekdayFormatter)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("结余 \(String(format: "%.2f", dailyBalance))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(dailyBalance >= 0 ? .primary : .red)
                    HStack(spacing: 12) {
                        Text("收入 \(String(format: "%.2f", dailyIncome))")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("支出 \(String(format: "%.2f", dailyExpense))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            
            if transactions.isEmpty {
                Text("当日无交易记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 使用List来启用滑动删除功能
                List {
                    ForEach(transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .listRowInsets(EdgeInsets()) // 移除List的默认边距
                            .listRowSeparator(.hidden) // 隐藏分隔线
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("删除") {
                                    deleteTransaction(transaction)
                                }
                                .tint(.red)
                                
                                Button("编辑") {
                                    editTransaction(transaction)
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(PlainListStyle()) // 使用朴素样式，避免额外的背景和边距
                .frame(height: CGFloat(transactions.count) * 70) // 根据内容动态调整高度，假设每行大约70高
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .sheet(item: $transactionToEdit) { transaction in
            TransactionEditView(transaction: transaction, viewModel: viewModel)
        }
    }
    
    private func editTransaction(_ transaction: Transaction) {
        transactionToEdit = transaction
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        viewModel.deleteTransaction(transaction: transaction)
    }

    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // 例如 "星期一"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    static let dateFormatter: DateFormatter = { // 新增 dateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    // 根据时间范围格式化日期标题
    private func formattedDateTitle(for date: Date, range: TransactionHistoryView.TimeRange) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let calendar = Calendar.current

        switch range {
        case .day:
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        case .week:
            // 显示周的起始日期，例如 "yyyy年MM月dd日 开始的一周"
            // 或者显示为 "yyyy年 第ww周"
            let year = calendar.component(.yearForWeekOfYear, from: date)
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            // 获取周的结束日期
            guard let endDateOfWeek = calendar.date(byAdding: .day, value: 6, to: date) else {
                return "\(year)年 第\(weekOfYear)周"
            }
//            let endDay = calendar.component(.day, from: endDateOfWeek)
//            let endMonth = calendar.component(.month, from: endDateOfWeek)
            
            let startDateFormatter = DateFormatter()
            startDateFormatter.locale = Locale(identifier: "zh_CN")
            startDateFormatter.dateFormat = "yyyy年MM月dd日"
            let startDateString = startDateFormatter.string(from: date)
            
            let endDateFormatter = DateFormatter()
            endDateFormatter.locale = Locale(identifier: "zh_CN")

            // 如果周的开始和结束在同一个月
            if calendar.isDate(date, equalTo: endDateOfWeek, toGranularity: .month) {
                 endDateFormatter.dateFormat = "d日"
                 let endDateString = endDateFormatter.string(from: endDateOfWeek)
                 return "\(startDateString) - \(endDateString)"
            } else {
                endDateFormatter.dateFormat = "MM月dd日"
                let endDateString = endDateFormatter.string(from: endDateOfWeek)
                return "\(startDateString) - \(endDateString)"
            }

        case .month:
            formatter.dateFormat = "yyyy年MM月"
            return formatter.string(from: date)
        case .quarter:
            let year = calendar.component(.year, from: date)
            let quarter = calendar.component(.quarter, from: date)
            return "\(year)年 第\(quarter)季度"
        case .year:
            formatter.dateFormat = "yyyy年"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    let previewDate = Date()
    let calendar = Calendar.current

    let sampleTransactionsForDay: [Transaction] = [
        Transaction(amount: 38.00, date: previewDate, category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "微信", note: ""),
        Transaction(amount: 248.00, date: previewDate, category: "日用百货", description: "超市购物", type: .expense, paymentMethod: "支付宝", note: "")
    ]
    
    let sampleTransactionsForWeek: [Transaction] = [
        Transaction(amount: 125.00, date: calendar.date(byAdding: .day, value: -1, to: previewDate)!, category: "交通", description: "公交", type: .expense, paymentMethod: "云闪付", note: ""),
        Transaction(amount: 50.00, date: calendar.date(byAdding: .day, value: 1, to: previewDate)!, category: "零食", description: "便利店", type: .expense, paymentMethod: "微信", note: "")
    ]

    let viewModel = TransactionViewModel(context: PersistenceController.preview.container.viewContext)

    // 获取周一作为周视图的date
    var gregorianCalendar = Calendar(identifier: .gregorian)
    gregorianCalendar.firstWeekday = 2 // Monday
    let startOfWeek = gregorianCalendar.date(from: gregorianCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: previewDate))!

    // 获取月初作为月视图的date
    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: previewDate))!
    
    // 获取季度初作为季度视图的date
    let quarter = calendar.component(.quarter, from: previewDate)
    let yearForQuarter = calendar.component(.year, from: previewDate)
    let firstMonthOfQuarter = (quarter - 1) * 3 + 1
    let startOfQuarter = calendar.date(from: DateComponents(year: yearForQuarter, month: firstMonthOfQuarter, day: 1))!

    // 获取年初作为年视图的date
    let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: previewDate))!


    return ScrollView {
        VStack {
            DailyTransactionListView(date: previewDate, transactions: sampleTransactionsForDay, timeRange: .day)
                .environmentObject(viewModel)
                .previewDisplayName("日视图")

            DailyTransactionListView(date: startOfWeek, transactions: sampleTransactionsForWeek, timeRange: .week)
                .environmentObject(viewModel)
                .previewDisplayName("周视图")

            DailyTransactionListView(date: startOfMonth, transactions: sampleTransactionsForDay, timeRange: .month)
                .environmentObject(viewModel)
                .previewDisplayName("月视图")

            DailyTransactionListView(date: startOfQuarter, transactions: sampleTransactionsForWeek, timeRange: .quarter)
                .environmentObject(viewModel)
                .previewDisplayName("季度视图")

            DailyTransactionListView(date: startOfYear, transactions: sampleTransactionsForDay, timeRange: .year)
                .environmentObject(viewModel)
                .previewDisplayName("年视图")

            DailyTransactionListView(date: previewDate, transactions: [], timeRange: .day) // 空交易记录的情况
                .environmentObject(viewModel)
                .previewDisplayName("空日视图")
        }
    }
}
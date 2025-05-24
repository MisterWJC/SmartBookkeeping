//
//  TransactionHistoryView.swift
//  SmartBookkeeping_LingMa2
//  账单明细的主视图。它将包含顶部的“账单明细”标题、一个日历图标、时间范围选择器（本月、上月、本季度、本年）、总支出和总收入的概览，以及一个按日期分组的交易列表（使用前面创建的 DailyTransactionListView ）。
//  Created by JasonWang on 2025/5/27.
//

import SwiftUI

struct TransactionHistoryView: View {
    @ObservedObject var viewModel: TransactionViewModel // 从外部传入
    @State private var selectedTimeRange: TimeRange = .currentMonth

    enum TimeRange: String, CaseIterable, Identifiable {
        case currentMonth = "本月"
        case lastMonth = "上月"
        case currentQuarter = "本季度"
        case currentYear = "本年"
        var id: String { self.rawValue }
    }

    // 根据选择的时间范围筛选和分组交易
    private var filteredAndGroupedTransactions: [Date: [Transaction]] {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date
        var endDate: Date = now

        switch selectedTimeRange {
        case .currentMonth:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        case .lastMonth:
            let firstOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            endDate = calendar.date(byAdding: .day, value: -1, to: firstOfCurrentMonth)!
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate))!
        case .currentQuarter:
            let quarter = calendar.component(.quarter, from: now)
            let year = calendar.component(.year, from: now)
            let firstMonthOfQuarter = (quarter - 1) * 3 + 1
            startDate = calendar.date(from: DateComponents(year: year, month: firstMonthOfQuarter, day: 1))!
        case .currentYear:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now))!
        }
        
        let filtered = viewModel.transactions.filter { $0.date >= startDate && $0.date <= endDate }
        // 按日期（忽略时间）分组
        return Dictionary(grouping: filtered) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
    }
    
    private var sortedDates: [Date] {
        filteredAndGroupedTransactions.keys.sorted(by: >) // 日期降序排列
    }

    private var totalExpenseInSelectedRange: Double {
        filteredAndGroupedTransactions.values.flatMap { $0 }
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalIncomeInSelectedRange: Double {
        filteredAndGroupedTransactions.values.flatMap { $0 }
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部概览区域
                VStack {
                    Picker("选择时间范围", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("总支出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("¥\(totalExpenseInSelectedRange, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("总收入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("¥\(totalIncomeInSelectedRange, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(UIColor.systemBackground)) // 确保背景色
                
                // 交易列表
                ScrollView {
                    if sortedDates.isEmpty {
                        Text("当前时间范围无交易记录")
                            .foregroundColor(.secondary)
                            .padding(.top, 50)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedDates, id: \.self) { date in
                                if let transactionsForDate = filteredAndGroupedTransactions[date] {
                                    DailyTransactionListView(date: date, transactions: transactionsForDate.sorted(by: { $0.date > $1.date }))
                                }
                            }
                        }
                        .padding(.top) // 给列表顶部一些间距
                    }
                }
                .background(Color(UIColor.secondarySystemBackground)) // 列表背景色，使其与顶部区域区分
                .edgesIgnoringSafeArea(.bottom) // 允许列表滚动到底部安全区域
            }
            .navigationTitle("账单明细")
            .navigationBarItems(trailing: Button(action: {
                // TODO: 实现日历选择功能
                print("日历按钮被点击")
            }) {
                Image(systemName: "calendar")
            })
        }
    }
}

#Preview {
    // It's generally good practice to do setup as cleanly as possible.
    // Let's prepare the viewModel and its data first.
    
    let setupViewModel: () -> TransactionViewModel = {
        // 1. Get the preview context from your PersistenceController
        let previewContext = PersistenceController.preview.container.viewContext

        // 2. Create the TransactionViewModel with the context
        let viewModel = TransactionViewModel(context: previewContext)
        
        // 3. Add your sample data
        let today = Date()
        let calendar = Calendar.current
        viewModel.addTransaction(Transaction(amount: 38.00, date: calendar.date(byAdding: .day, value: -1, to: today)!, category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "微信", note: ""))
        viewModel.addTransaction(Transaction(amount: 248.00, date: calendar.date(byAdding: .day, value: -1, to: today)!, category: "日用百货", description: "超市购物", type: .expense, paymentMethod: "支付宝", note: ""))
        viewModel.addTransaction(Transaction(amount: 12500.00, date: calendar.date(byAdding: .day, value: -2, to: today)!, category: "工资收入", description: "工资收入", type: .income, paymentMethod: "银行卡", note: ""))
        viewModel.addTransaction(Transaction(amount: 168.00, date: calendar.date(byAdding: .day, value: -2, to: today)!, category: "交通出行", description: "打车", type: .expense, paymentMethod: "支付宝", note: ""))
        viewModel.addTransaction(Transaction(amount: 50.00, date: calendar.date(byAdding: .month, value: -1, to: today)!, category: "餐饮美食", description: "咖啡", type: .expense, paymentMethod: "微信", note: ""))
        
        return viewModel
    }
    
    // 4. Return the View you want to preview, injecting the prepared ViewModel
    TransactionHistoryView(viewModel: setupViewModel())
}

//
//  TransactionHistoryView.swift
//  SmartBookkeeping
//  账单明细的主视图。它将包含顶部的“账单明细”标题、一个日历图标、时间范围选择器（本月、上月、本季度、本年）、总支出和总收入的概览，以及一个按日期分组的交易列表（使用前面创建的 DailyTransactionListView ）。
//  Created by JasonWang on 2025/5/27.
//

import SwiftUI

struct TransactionHistoryView: View {
    @ObservedObject var viewModel: TransactionViewModel // 从外部传入
    @State private var selectedTimeRange: TimeRange = .month // 默认按月分组
    @State private var selectedAccount: String = "全部账户"
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showingCustomDatePicker = false

    private var allAccounts: [String] {
        ["全部账户"] + Array(Set(viewModel.transactions.map { $0.paymentMethod }.filter { !$0.isEmpty })).sorted()
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "天"
        case week = "周"
        case month = "月"
        case quarter = "季度"
        case year = "年"
        case custom = "自定义"
        var id: String { self.rawValue }
    }

    // 根据选择的时间范围（分组粒度）对所有交易进行分组
    private var filteredAndGroupedTransactions: [Date: [Transaction]] {
        let calendar = Calendar.current
        
        // 使用辅助函数获取分组键
        func groupKey(for transaction: Transaction, by range: TimeRange) -> Date {
            let date = transaction.date
            switch range {
            case .day:
                return calendar.startOfDay(for: date)
            case .week:
                // 获取当前日期所在周的周一
                // weekday 1 = Sunday, 2 = Monday, ..., 7 = Saturday. 我们希望周一是每周的开始。
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                return calendar.date(from: components)! // 这通常返回周日或周一，取决于地区设置
                                                        // 为了统一为周一，可以进一步调整：
//                guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
//                    return calendar.startOfDay(for: date) // fallback
//                }
//                let weekday = calendar.component(.weekday, from: startOfWeek)
//                if calendar.firstWeekday == 1 && weekday == 1 { // Sunday is first day, and current is Sunday
//                    return calendar.date(byAdding: .day, value: 1, to: startOfWeek) ?? startOfWeek // Move to Monday
//                } else if calendar.firstWeekday == 2 && weekday == 2 { // Monday is first day, and current is Monday
//                    return startOfWeek
//                } else if weekday == 1 { // Sunday, and Monday is not first day
//                     return calendar.date(byAdding: .day, value: -6, to: startOfWeek) ?? startOfWeek // Should be start of this week's Monday
//                }
//                // A more robust way for Monday as start of week
                var gregorianCalendar = Calendar(identifier: .gregorian)
                gregorianCalendar.firstWeekday = 2 // Monday
                return gregorianCalendar.date(from: gregorianCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!

            case .month:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            case .quarter:
                let quarter = calendar.component(.quarter, from: date)
                let year = calendar.component(.year, from: date)
                let firstMonthOfQuarter = (quarter - 1) * 3 + 1
                return calendar.date(from: DateComponents(year: year, month: firstMonthOfQuarter, day: 1))!
            case .year:
                return calendar.date(from: calendar.dateComponents([.year], from: date))!
            case .custom:
                // 对于自定义时间范围，按天分组
                return calendar.startOfDay(for: date)
            }
        }
        
        // 首先根据账户筛选
        var accountFilteredTransactions = viewModel.transactions.filter {
            selectedAccount == "全部账户" || $0.paymentMethod == selectedAccount
        }
        
        // 如果是自定义时间范围，进一步按日期筛选
        if selectedTimeRange == .custom {
            accountFilteredTransactions = accountFilteredTransactions.filter { transaction in
                let transactionDate = Calendar.current.startOfDay(for: transaction.date)
                let startDate = Calendar.current.startOfDay(for: customStartDate)
                let endDate = Calendar.current.startOfDay(for: customEndDate)
                return transactionDate >= startDate && transactionDate <= endDate
            }
        }
        
        // 然后对筛选后的交易进行分组
        return Dictionary(grouping: accountFilteredTransactions) { transaction in
            groupKey(for: transaction, by: selectedTimeRange)
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
                    HStack {
                        Picker("时间范围", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedTimeRange) { newValue in
                            if newValue == .custom {
                                showingCustomDatePicker = true
                            }
                        }
                        
                        // 如果是自定义时间范围，显示选择的日期范围
                        if selectedTimeRange == .custom {
                            Button(action: {
                                showingCustomDatePicker = true
                            }) {
                                Text("\(formatDate(customStartDate)) - \(formatDate(customEndDate))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        Picker("账户", selection: $selectedAccount) {
                            ForEach(allAccounts, id: \.self) { account in
                                Text(account).tag(account)
                            }
                        }
                        .pickerStyle(.menu)

                        Spacer() // 将选择器推到左边
                    }
                    .padding()

                    // 结余信息
                    HStack {
                        Spacer()
                        VStack {
                            Text("结余")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", totalIncomeInSelectedRange - totalExpenseInSelectedRange))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(totalIncomeInSelectedRange - totalExpenseInSelectedRange >= 0 ? .primary : .red)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // 收入支出详情
                    HStack {
                        VStack(alignment: .leading) {
                            Text("收入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", totalIncomeInSelectedRange))
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("支出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", totalExpenseInSelectedRange))
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
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
                                    DailyTransactionListView(date: date, transactions: transactionsForDate.sorted(by: { $0.date > $1.date }), timeRange: selectedTimeRange)
                                        .environmentObject(viewModel) // 注入ViewModel
                                }
                            }
                        }
                        .padding(.top) // 给列表顶部一些间距
                    }
                }
                .background(Color(UIColor.secondarySystemBackground)) // 列表背景色，使其与顶部区域区分
                // .edgesIgnoringSafeArea(.bottom) // 移除此行以避免与 TabView 重叠
            }
            .navigationTitle("账单明细")
            // 移除了右上角的日历按钮
        }
        .onAppear {
            // 可以在这里加载初始数据或执行其他设置
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            CustomDateRangePickerView(
                startDate: $customStartDate,
                endDate: $customEndDate,
                isPresented: $showingCustomDatePicker
            )
        }
        // 在NavigationView的顶层注入ViewModel，使其对所有子视图可用
        // 如果DailyTransactionListView是唯一需要它的地方，则在上面直接注入也可以
        // 但通常在父视图或根视图注入更常见
        // .environmentObject(viewModel) // 考虑是否在此处注入，或者在SmartBookkeepingApp中注入
    }
    
    // 格式化日期显示
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
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

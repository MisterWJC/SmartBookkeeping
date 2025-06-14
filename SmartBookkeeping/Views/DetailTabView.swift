//
//  DetailTabView.swift
//  SmartBookkeeping
//
//  明细主视图，包含账单明细和账户明细的切换
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct DetailTabView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @State private var selectedDetailType: DetailType = .transactions
    @State private var selectedAccount: String = "全部账户"
    
    enum DetailType: String, CaseIterable {
        case transactions = "账单明细"
        case accounts = "账户明细"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部分段控制器
                Picker("明细类型", selection: $selectedDetailType) {
                    ForEach(DetailType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
                
                // 内容区域
                Group {
                    switch selectedDetailType {
                    case .transactions:
                        TransactionHistoryContentView(
                            viewModel: viewModel,
                            selectedAccount: $selectedAccount
                        )
                    case .accounts:
                        AccountDetailView(
                            viewModel: viewModel,
                            selectedDetailType: $selectedDetailType,
                            selectedAccount: $selectedAccount
                        )
                    }
                }
            }
        }
    }
}

// 将TransactionHistoryView的内容提取为独立组件
struct TransactionHistoryContentView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @State private var selectedTimeRange: TimeRange = .month
    @Binding var selectedAccount: String
    @State private var selectedCategory: String = "全部类别"

    private var allAccounts: [String] {
        ["全部账户"] + Array(Set(viewModel.transactions.map { $0.paymentMethod }.filter { !$0.isEmpty })).sorted()
    }
    
    private var allCategories: [String] {
        ["全部类别"] + Array(Set(viewModel.transactions.map { $0.category }.filter { !$0.isEmpty })).sorted()
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "天"
        case week = "周"
        case month = "月"
        case quarter = "季度"
        case year = "年"
        var id: String { self.rawValue }
    }

    private var filteredAndGroupedTransactions: [Date: [Transaction]] {
        let calendar = Calendar.current
        
        func groupKey(for transaction: Transaction, by range: TimeRange) -> Date {
            let date = transaction.date
            switch range {
            case .day:
                return calendar.startOfDay(for: date)
            case .week:
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
            }
        }
        
        let accountFilteredTransactions = viewModel.transactions.filter {
            (selectedAccount == "全部账户" || $0.paymentMethod == selectedAccount) &&
            (selectedCategory == "全部类别" || $0.category == selectedCategory)
        }
        
        return Dictionary(grouping: accountFilteredTransactions) { transaction in
            groupKey(for: transaction, by: selectedTimeRange)
        }
    }
    
    private var sortedDates: [Date] {
        filteredAndGroupedTransactions.keys.sorted(by: >)
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
    
    // 转换函数：将本地TimeRange转换为TransactionHistoryView.TimeRange
    private func convertToTransactionHistoryTimeRange(_ timeRange: TimeRange) -> TransactionHistoryView.TimeRange {
        switch timeRange {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .quarter:
            return .quarter
        case .year:
            return .year
        }
    }

    var body: some View {
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

                    Picker("账户", selection: $selectedAccount) {
                        ForEach(allAccounts, id: \.self) { account in
                            Text(account).tag(account)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("类别", selection: $selectedCategory) {
                        ForEach(allCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
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
            .background(Color(UIColor.systemBackground))
            
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
                                DailyTransactionListView(date: date, transactions: transactionsForDate.sorted(by: { $0.date > $1.date }), timeRange: convertToTransactionHistoryTimeRange(selectedTimeRange))
                                    .environmentObject(viewModel)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

#Preview {
    let setupViewModel: () -> TransactionViewModel = {
        let previewContext = PersistenceController.preview.container.viewContext
        let viewModel = TransactionViewModel(context: previewContext)
        
        let today = Date()
        let calendar = Calendar.current
        viewModel.addTransaction(Transaction(amount: 38.00, date: calendar.date(byAdding: .day, value: -1, to: today)!, category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "微信", note: ""))
        viewModel.addTransaction(Transaction(amount: 248.00, date: calendar.date(byAdding: .day, value: -1, to: today)!, category: "日用百货", description: "超市购物", type: .expense, paymentMethod: "支付宝", note: ""))
        viewModel.addTransaction(Transaction(amount: 12500.00, date: calendar.date(byAdding: .day, value: -2, to: today)!, category: "工资收入", description: "工资收入", type: .income, paymentMethod: "招商银行", note: ""))
        viewModel.addTransaction(Transaction(amount: 168.00, date: calendar.date(byAdding: .day, value: -2, to: today)!, category: "交通出行", description: "打车", type: .expense, paymentMethod: "支付宝", note: ""))
        
        return viewModel
    }
    
    @State var previewSelectedAccount = "全部账户"
    
    DetailTabView(viewModel: setupViewModel())
}
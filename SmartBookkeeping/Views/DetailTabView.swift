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
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showingCustomDatePicker = false

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
        case custom = "自定义"
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
            case .custom:
                return calendar.startOfDay(for: date)
            }
        }
        
        let accountFilteredTransactions = viewModel.transactions.filter {
            (selectedAccount == "全部账户" || $0.paymentMethod == selectedAccount) &&
            (selectedCategory == "全部类别" || $0.category == selectedCategory)
        }
        
        // 如果是自定义时间范围，进一步按日期筛选
        let finalFilteredTransactions: [Transaction]
        if selectedTimeRange == .custom {
            finalFilteredTransactions = accountFilteredTransactions.filter { transaction in
                let transactionDate = Calendar.current.startOfDay(for: transaction.date)
                let startDate = Calendar.current.startOfDay(for: customStartDate)
                let endDate = Calendar.current.startOfDay(for: customEndDate)
                return transactionDate >= startDate && transactionDate <= endDate
            }
        } else {
            finalFilteredTransactions = accountFilteredTransactions
        }
        
        return Dictionary(grouping: finalFilteredTransactions) { transaction in
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
        case .custom:
            return .custom
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部概览区域
            VStack {
                HStack(spacing: 8) {
                    VStack {
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
                    }
                    .frame(maxWidth: .infinity)

                    Picker("账户", selection: $selectedAccount) {
                        ForEach(allAccounts, id: \.self) { account in
                            Text(account).tag(account)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    
                    Picker("类别", selection: $selectedCategory) {
                        ForEach(allCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
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
                    EmptyStateView()
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
        .sheet(isPresented: $showingCustomDatePicker) {
            CustomDateRangePickerView(
                startDate: $customStartDate,
                endDate: $customEndDate,
                isPresented: $showingCustomDatePicker
            )
        }
    }
    
    // 格式化日期显示
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - 空状态引导视图
struct EmptyStateView: View {
    @State private var showingAIGuide = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 空状态图标
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 1.0 : 0.7)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    .shadow(color: .blue.opacity(0.5), radius: pulseAnimation ? 10 : 5)
            }
            
            VStack(spacing: 12) {
                Text("欢迎使用智能记账助手！")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("点击下方按钮开始您的第一笔记账")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: { // 按钮要执行的操作
                    showingAIGuide = true
                }) { // 自定义按钮的外观 (Label)
                    Text("体验AI记账")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity) // 将修饰符应用在 Text 上
                        .padding(.vertical, 14)    // 而不是 Button 上
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                } // Button 的 Label 定义结束

                // --- 手动记账按钮 ---
                Button(action: {
                    // 切换到记账页面
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToFormTab"), object: nil)
                }) {
                    Text("手动记账")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            pulseAnimation = true
        }
        .sheet(isPresented: $showingAIGuide) {
            InitialSetupView()
                .interactiveDismissDisabled(false)
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
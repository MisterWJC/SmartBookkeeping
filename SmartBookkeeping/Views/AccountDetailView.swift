//
//  AccountDetailView.swift
//  SmartBookkeeping
//
//  账户明细视图，用于显示不同账户的资产余额和总资产统计
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI
import CoreData

struct AccountDetailView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @StateObject private var accountViewModel = AccountViewModel()
    @Binding var selectedDetailType: DetailTabView.DetailType
    @Binding var selectedAccount: String
    @State private var showingCreateAccount = false
    

    
    // 账户分组数据
    private var accountSummary: [AccountSummary] {
        return accountViewModel.getAccountSummary(transactions: getTransactionItems())
            .sorted { $0.balance > $1.balance }
    }
    
    // 获取TransactionItem数据的辅助方法
    private func getTransactionItems() -> [TransactionItem] {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionItem.date, ascending: false)]
        
        do {
            return try viewModel.managedObjectContext.fetch(request)
        } catch {
            print("获取TransactionItem数据失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // 总资产（只计算计入资产的账户）
    private var totalAssets: Double {
        accountSummary.filter { summary in
            guard let accountItem = accountViewModel.getAccount(by: summary.accountName) else {
                return summary.accountType == .asset // 默认资产类型计入总资产
            }
            return accountItem.includeInAssets && summary.balance > 0
        }.reduce(0) { $0 + $1.balance }
    }
    
    // 总负债（负余额且计入资产的账户）
    private var totalLiabilities: Double {
        accountSummary.filter { summary in
            guard let accountItem = accountViewModel.getAccount(by: summary.accountName) else {
                return summary.accountType == .asset // 默认资产类型计入总资产
            }
            return accountItem.includeInAssets && summary.balance < 0
        }.reduce(0) { $0 + $1.balance }
    }
    
    // 净资产
    private var netAssets: Double {
        totalAssets + totalLiabilities
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部总资产概览 - 优化UI设计
            VStack(spacing: 0) {
                // 净资产大数字显示
                VStack(spacing: 8) {
                    Text(String(format: "%.2f", netAssets))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // 总资产和总负债对比
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", totalAssets))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("总资产")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", abs(totalLiabilities)))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                            Text("总负债")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
                .padding(.horizontal, 20)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground).opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 账户列表
            List {
                // 储蓄账户
                if !savingsAccounts.isEmpty {
                    AccountSectionListView(title: "储蓄账户", 
                                     accounts: savingsAccounts,
                                     totalAmount: savingsAccounts.reduce(0) { $0 + $1.balance },
                                     viewModel: viewModel,
                                     accountViewModel: accountViewModel,
                                     selectedDetailType: $selectedDetailType,
                                     selectedAccount: $selectedAccount)
                }
                
                // 虚拟账户
                if !virtualAccounts.isEmpty {
                    AccountSectionListView(title: "虚拟账户", 
                                     accounts: virtualAccounts,
                                     totalAmount: virtualAccounts.reduce(0) { $0 + $1.balance },
                                     viewModel: viewModel,
                                     accountViewModel: accountViewModel,
                                     selectedDetailType: $selectedDetailType,
                                     selectedAccount: $selectedAccount)
                }
                
                // 投资账户
                if !investmentAccounts.isEmpty {
                    AccountSectionListView(title: "投资账户", 
                                     accounts: investmentAccounts,
                                     totalAmount: investmentAccounts.reduce(0) { $0 + $1.balance },
                                     viewModel: viewModel,
                                     accountViewModel: accountViewModel,
                                     selectedDetailType: $selectedDetailType,
                                     selectedAccount: $selectedAccount)
                }
                
                // 信用账户
                if !creditAccounts.isEmpty {
                    AccountSectionListView(title: "信用账户", 
                                     accounts: creditAccounts,
                                     totalAmount: creditAccounts.reduce(0) { $0 + $1.balance },
                                     viewModel: viewModel,
                                     accountViewModel: accountViewModel,
                                     selectedDetailType: $selectedDetailType,
                                     selectedAccount: $selectedAccount)
                }
                
                // 添加新账户按钮
                Section {
                    Button(action: {
                        showingCreateAccount = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            Text("添加新账户")
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .background(Color(UIColor.systemBackground))
                }

            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .sheet(isPresented: $showingCreateAccount) {
            AccountEditView(transactionViewModel: viewModel) { name, type, balance in
                // 账户创建成功后刷新数据
                accountViewModel.fetchAccounts()
            }
        }
        .onAppear {
            // 页面出现时刷新账户数据
            accountViewModel.fetchAccounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccountDeleted"))) { _ in
            // 监听账户删除通知，自动刷新数据
            accountViewModel.fetchAccounts()
        }
    }
    
    // 按分类分组的账户
    private var savingsAccounts: [AccountSummary] {
        accountSummary.filter { $0.accountCategory == .savings }
    }
    
    private var virtualAccounts: [AccountSummary] {
        accountSummary.filter { $0.accountCategory == .virtual }
    }
    
    private var investmentAccounts: [AccountSummary] {
        accountSummary.filter { $0.accountCategory == .investment }
    }
    
    private var creditAccounts: [AccountSummary] {
        accountSummary.filter { $0.accountCategory == .credit }
    }
}



// 账户分组视图
struct AccountSectionView: View {
    let title: String
    let accounts: [AccountSummary]
    let totalAmount: Double
    @ObservedObject var viewModel: TransactionViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 分组标题
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f", totalAmount))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(totalAmount >= 0 ? .primary : .red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemBackground))
            
            // 账户列表
            ForEach(accounts, id: \.accountName) { account in
                AccountRowView(account: account, viewModel: viewModel)
            }
        }
    }
}

// 适用于List的账户分组视图
struct AccountSectionListView: View {
    let title: String
    let accounts: [AccountSummary]
    let totalAmount: Double
    @ObservedObject var viewModel: TransactionViewModel
    @ObservedObject var accountViewModel: AccountViewModel
    @Binding var selectedDetailType: DetailTabView.DetailType
    @Binding var selectedAccount: String
    
    var body: some View {
        Section {
            ForEach(accounts, id: \.accountName) { account in
                AccountRowListView(
                    account: account, 
                    viewModel: viewModel,
                    accountViewModel: accountViewModel,
                    selectedDetailType: $selectedDetailType,
                    selectedAccount: $selectedAccount
                )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        } header: {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.none)
                Spacer()
                Text(String(format: "%.2f", totalAmount))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(totalAmount >= 0 ? .primary : .red)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

// 单个账户行视图
struct AccountRowView: View {
    let account: AccountSummary
    @ObservedObject var viewModel: TransactionViewModel
    @State private var showingEditSheet = false
    @State private var navigateToTransactions = false
    
    var body: some View {
        HStack {
            // 账户图标
            Image(systemName: getAccountIcon(for: account.accountType))
                .foregroundColor(getAccountColor(for: account.accountType))
                .frame(width: 24, height: 24)
            
            // 账户名称
            Text(account.accountName)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // 余额
            Text(String(format: "%.2f", account.balance))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(account.balance >= 0 ? .primary : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            navigateToTransactions = true
        }
        .swipeActions(edge: .trailing) {
            Button("编辑") {
                showingEditSheet = true
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingEditSheet) {
            AccountEditView(account: account, transactionViewModel: viewModel)
        }
        .background(
            NavigationLink(
                destination: FilteredTransactionView(accountName: account.accountName)
                    .environmentObject(viewModel),
                isActive: $navigateToTransactions
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}

// 适用于List的单个账户行视图
struct AccountRowListView: View {
    let account: AccountSummary
    @ObservedObject var viewModel: TransactionViewModel
    @ObservedObject var accountViewModel: AccountViewModel
    @State private var showingEditSheet = false
    @Binding var selectedDetailType: DetailTabView.DetailType
    @Binding var selectedAccount: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 账户图标 - 优化设计
            ZStack {
                Circle()
                    .fill(getAccountColor(for: account.accountCategory).opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: getAccountIcon(for: account.accountCategory))
                    .foregroundColor(getAccountColor(for: account.accountCategory))
                    .font(.system(size: 18, weight: .medium))
            }
            
            // 账户信息
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(getAccountTypeDisplayName(for: account.accountCategory))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 余额显示 - 优化样式
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", account.balance))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(account.balance >= 0 ? .primary : .red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // 切换到账单明细页面并设置账户筛选
            selectedDetailType = .transactions
            selectedAccount = account.accountName
        }
        .swipeActions(edge: .trailing) {
            Button("编辑") {
                showingEditSheet = true
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingEditSheet) {
            AccountEditView(account: account, transactionViewModel: viewModel)
        }
     }
     
     private func getAccountIcon(for category: AccountCategory) -> String {
         return category.icon
     }
     
     private func getAccountColor(for category: AccountCategory) -> Color {
         return category.color
     }
     
     private func getAccountTypeDisplayName(for category: AccountCategory) -> String {
         return category.displayName
     }
}

// 辅助函数
func getAccountIcon(for type: AccountType) -> String {
    switch type {
    case .asset:
        return "banknote"
    case .liability:
        return "creditcard"
    }
}

func getAccountColor(for type: AccountType) -> Color {
    switch type {
    case .asset:
        return .green
    case .liability:
        return .red
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDetailType: DetailTabView.DetailType = .accounts
        @State private var selectedAccount: String = "全部账户"
        
        private func setupViewModel() -> TransactionViewModel {
            let previewContext = PersistenceController.preview.container.viewContext
            let viewModel = TransactionViewModel(context: previewContext)
            
            // 添加示例数据
            let today = Date()
            viewModel.addTransaction(Transaction(amount: 300.00, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "现金", note: ""))
            viewModel.addTransaction(Transaction(amount: 165982.67, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "招商银行", note: ""))
            viewModel.addTransaction(Transaction(amount: 229.00, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "交通银行", note: ""))
            viewModel.addTransaction(Transaction(amount: 555.48, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "建设银行", note: ""))
            viewModel.addTransaction(Transaction(amount: 57960.00, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "中信银行", note: ""))
            viewModel.addTransaction(Transaction(amount: 643.00, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "WeChat", note: ""))
            viewModel.addTransaction(Transaction(amount: 3010.25, date: today, category: "工资收入", description: "工资", type: .income, paymentMethod: "Alipay", note: ""))
            
            // 添加一些支出
            viewModel.addTransaction(Transaction(amount: 50.00, date: today, category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "现金", note: ""))
            viewModel.addTransaction(Transaction(amount: 100.00, date: today, category: "交通出行", description: "打车", type: .expense, paymentMethod: "WeChat", note: ""))
            
            return viewModel
        }
        
        var body: some View {
            AccountDetailView(
                viewModel: setupViewModel(),
                selectedDetailType: $selectedDetailType,
                selectedAccount: $selectedAccount
            )
        }
    }
    
    return PreviewWrapper()
}
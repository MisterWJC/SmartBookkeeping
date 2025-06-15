//
//  AccountEditView.swift
//  SmartBookkeeping
//
//  账户编辑视图，用于编辑账户名称、余额、是否计入资产和备注
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI
import CoreData

struct AccountEditView: View {
    let account: AccountSummary?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountViewModel = AccountViewModel()
    @ObservedObject var transactionViewModel: TransactionViewModel
    let onAccountCreated: ((String, AccountType, Double) -> Void)?
    
    @State private var accountName: String
    @State private var balance: String
    // 余额基准日期默认为当前日期，不再需要用户选择
    @State private var accountType: AccountType
    @State private var accountCategory: AccountCategory
    @State private var includeInAssets: Bool
    @State private var note: String
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingTransactionWarning = false
    
    private var isNewAccount: Bool {
        return account == nil
    }
    
    private var accountItem: AccountItem? {
        guard let account = account else { return nil }
        return accountViewModel.getAccount(by: account.accountName)
    }
    
    init(account: AccountSummary? = nil, transactionViewModel: TransactionViewModel, onAccountCreated: ((String, AccountType, Double) -> Void)? = nil) {
        self.account = account
        self.transactionViewModel = transactionViewModel
        self.onAccountCreated = onAccountCreated
        
        if let account = account {
            _accountName = State(initialValue: account.accountName)
            _balance = State(initialValue: String(format: "%.2f", account.balance))
            _accountType = State(initialValue: account.accountType)
            _accountCategory = State(initialValue: account.accountCategory)
            _includeInAssets = State(initialValue: account.accountType == .asset)
        } else {
            _accountName = State(initialValue: "")
            _balance = State(initialValue: "0.00")
            _accountType = State(initialValue: .asset)
            _accountCategory = State(initialValue: .savings)
            _includeInAssets = State(initialValue: true)
        }
        
        _note = State(initialValue: "")
    }
    
    // 获取TransactionItem数据的辅助方法
    private func getTransactionItems() -> [TransactionItem] {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionItem.date, ascending: false)]
        
        do {
            return try transactionViewModel.managedObjectContext.fetch(request)
        } catch {
            print("获取TransactionItem数据失败: \(error.localizedDescription)")
            return []
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("账户信息")) {
                    TextField("账户名称", text: $accountName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("余额", text: $balance)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("账户分类", selection: $accountCategory) {
                        ForEach(AccountCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: accountCategory) { newCategory in
                        // 根据账户分类自动设置账户类型
                        accountType = (newCategory == .credit) ? .liability : .asset
                        includeInAssets = (accountType == .asset)
                    }
                    
                    // 显示自动匹配的账户类型（只读）
                    HStack {
                        Text("账户类型")
                        Spacer()
                        Text(accountType.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("计入总资产", isOn: $includeInAssets)
                }
                
                Section(header: Text("备注")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
                
                Section {
                    if !isNewAccount {
                        Button(action: checkAndShowDeleteConfirmation) {
                            Text("删除账户")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
            .navigationTitle(isNewAccount ? "创建账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isNewAccount ? "创建" : "保存") {
                        saveChanges()
                    }
                    .disabled(accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定") {
                    if alertMessage.contains("保存") || alertMessage.contains("创建") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .alert("删除账户", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("确定要删除此账户吗？此操作不可撤销。")
            }
            .alert("账户包含交易记录", isPresented: $showingTransactionWarning) {
                Button("取消", role: .cancel) { }
                Button("仅删除账户", role: .destructive) {
                    deleteAccount(deleteTransactions: false)
                }
                Button("删除账户和交易", role: .destructive) {
                    deleteAccount(deleteTransactions: true)
                }
            } message: {
                Text("此账户包含交易记录，请选择删除方式：")
            }
        }
    
    private func saveChanges() {
        // 验证输入
        guard !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "账户名称不能为空"
            showingAlert = true
            return
        }
        
        guard let balanceValue = Double(balance) else {
            alertMessage = "请输入有效的余额数字"
            showingAlert = true
            return
        }
        
        let trimmedName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查账户名称是否重复（除了当前编辑的账户）
        if let existingAccount = accountViewModel.getAccount(by: trimmedName),
           existingAccount != accountItem {
            alertMessage = "账户名称已存在，请使用其他名称"
            showingAlert = true
            return
        }
        
        if isNewAccount {
            // 创建新账户
            accountViewModel.createAccount(
                name: trimmedName,
                initialBalance: balanceValue,
                balanceDate: Date(), // 使用当前日期作为余额基准日期
                accountType: accountType.rawValue,
                accountCategory: accountCategory.rawValue,
                includeInAssets: includeInAssets,
                note: note
            )
            alertMessage = "账户创建成功"
            
            // 调用回调函数通知父视图
            onAccountCreated?(trimmedName, accountType, balanceValue)
        } else {
            // 更新现有账户
            guard let accountItem = accountItem else {
                alertMessage = "账户不存在"
                showingAlert = true
                return
            }
            
            // 计算新的初始余额，保持原有的余额基准日期
            let transactions = getTransactionItems()
            let currentCalculatedBalance = accountViewModel.calculateCurrentBalance(for: accountItem, transactions: transactions)
            let balanceDifference = balanceValue - currentCalculatedBalance
            let newInitialBalance = accountItem.initialBalance + balanceDifference
            
            accountViewModel.updateAccount(
                accountItem,
                name: trimmedName,
                initialBalance: newInitialBalance,
                balanceDate: accountItem.balanceDate ?? Date(), // 保持原有的余额基准日期
                accountType: accountType.rawValue,
                accountCategory: accountCategory.rawValue,
                includeInAssets: includeInAssets,
                note: note
            )
            alertMessage = "账户信息已保存"
        }
        
        showingAlert = true
    }
    
    private func checkAndShowDeleteConfirmation() {
        guard let accountItem = accountItem else { return }
        
        if accountViewModel.hasTransactions(for: accountItem) {
            showingTransactionWarning = true
        } else {
            showingDeleteConfirmation = true
        }
    }
    
    private func deleteAccount(deleteTransactions: Bool = false) {
        guard let accountItem = accountItem else { return }
        
        accountViewModel.deleteAccount(accountItem, deleteTransactions: deleteTransactions)
        
        // 发送账户删除通知
        NotificationCenter.default.post(name: NSNotification.Name("AccountDeleted"), object: nil)
        
        // 刷新交易数据和账户数据
        transactionViewModel.fetchTransactions()
        accountViewModel.fetchAccounts()
        
        // 关闭编辑页面
        dismiss()
        
        alertMessage = "账户已删除"
        showingAlert = true
    }
}

#Preview {
    AccountEditView(
        account: AccountSummary(accountName: "招商银行", balance: 165982.67, accountType: .asset, accountCategory: .savings),
        transactionViewModel: TransactionViewModel(context: PersistenceController.shared.container.viewContext)
    )
}
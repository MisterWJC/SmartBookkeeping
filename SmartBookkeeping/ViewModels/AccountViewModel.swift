//
//  AccountViewModel.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import CoreData
import SwiftUI

class AccountViewModel: ObservableObject {
    @Published var accounts: [AccountItem] = []
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        fetchAccounts()
    }
    
    // MARK: - Fetch Accounts
    func fetchAccounts() {
        let request: NSFetchRequest<AccountItem> = AccountItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AccountItem.sortOrder, ascending: true)]
        
        do {
            accounts = try context.fetch(request)
        } catch {
            print("Error fetching accounts: \(error)")
        }
    }
    
    // MARK: - Create Account
    func createAccount(name: String, initialBalance: Double, balanceDate: Date, accountType: String, accountCategory: String = "储蓄", includeInAssets: Bool, note: String = "", isDefault: Bool = false) {
        let newAccount = AccountItem(context: context)
        newAccount.id = UUID()
        newAccount.name = name
        newAccount.initialBalance = initialBalance
        newAccount.balanceDate = balanceDate
        newAccount.accountType = accountType
        newAccount.accountCategory = accountCategory
        newAccount.includeInAssets = includeInAssets
        newAccount.note = note
        newAccount.isDefault = isDefault
        newAccount.sortOrder = Int32(accounts.count)
        
        saveContext()
        fetchAccounts()
    }
    
    // MARK: - Update Account
    func updateAccount(_ account: AccountItem, name: String, initialBalance: Double, balanceDate: Date, accountType: String, accountCategory: String, includeInAssets: Bool, note: String, isDefault: Bool = false) {
        account.name = name
        account.initialBalance = initialBalance
        account.balanceDate = balanceDate
        account.accountType = accountType
        account.accountCategory = accountCategory
        account.includeInAssets = includeInAssets
        account.note = note
        account.isDefault = isDefault
        
        saveContext()
        fetchAccounts()
    }
    
    // MARK: - Delete Account
    func deleteAccount(_ account: AccountItem, deleteTransactions: Bool = false) {
        if deleteTransactions {
            // 删除该账户相关的所有交易记录
            let transactionRequest: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
            transactionRequest.predicate = NSPredicate(format: "paymentMethod == %@", account.name ?? "")
            
            do {
                let transactions = try context.fetch(transactionRequest)
                for transaction in transactions {
                    context.delete(transaction)
                }
            } catch {
                print("Error deleting transactions: \(error)")
            }
        }
        
        context.delete(account)
        saveContext()
        fetchAccounts()
        
        // 发送账户删除通知
        NotificationCenter.default.post(name: NSNotification.Name("AccountDeleted"), object: nil)
    }
    
    // MARK: - Delete Account by Name
    func deleteAccount(name: String, deleteTransactions: Bool = false) {
        guard let account = getAccount(by: name) else {
            print("Account with name \(name) not found")
            return
        }
        deleteAccount(account, deleteTransactions: deleteTransactions)
    }
    
    // MARK: - Get Account by Name
    func getAccount(by name: String) -> AccountItem? {
        return accounts.first { $0.name == name }
    }
    
    // MARK: - Calculate Current Balance
    func calculateCurrentBalance(for account: AccountItem, transactions: [TransactionItem]) -> Double {
        let accountName = account.name ?? ""
        let balanceDate = account.balanceDate ?? Date()
        let initialBalance = account.initialBalance
        
        // 计算余额基准日期之后创建的交易金额（使用timestamp而不是交易日期）
        let relevantTransactions = transactions.filter { transaction in
            guard let transactionTimestamp = transaction.timestamp,
                  transaction.paymentMethod == accountName else {
                return false
            }
            return transactionTimestamp >= balanceDate
        }
        
        let transactionSum = relevantTransactions.reduce(0.0) { sum, transaction in
            if transaction.type == "支出" {
                return sum - transaction.amount
            } else {
                return sum + transaction.amount
            }
        }
        
        return initialBalance + transactionSum
    }
    
    // MARK: - Get Account Summary
    func getAccountSummary(transactions: [TransactionItem]) -> [AccountSummary] {
        return accounts.map { account in
            let currentBalance = calculateCurrentBalance(for: account, transactions: transactions)
            return AccountSummary(
                accountName: account.name ?? "",
                balance: currentBalance,
                accountType: AccountType(rawValue: account.accountType ?? "资产") ?? .asset,
                accountCategory: AccountCategory(rawValue: account.accountCategory ?? "储蓄") ?? .savings
            )
        }
    }
    
    // MARK: - Check if Account has Transactions
    func hasTransactions(for account: AccountItem) -> Bool {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.predicate = NSPredicate(format: "paymentMethod == %@", account.name ?? "")
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Error checking transactions: \(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

// MARK: - Account Summary Model
struct AccountSummary {
    let accountName: String
    let balance: Double
    let accountType: AccountType
    let accountCategory: AccountCategory
}

enum AccountType: String, CaseIterable {
    case asset = "资产"
    case liability = "负债"
    
    var displayName: String {
        return self.rawValue
    }
}

enum AccountCategory: String, CaseIterable {
    case savings = "储蓄"      // 银行卡
    case virtual = "虚拟"      // 支付宝、微信、饭卡、公交卡
    case investment = "投资"   // 基金、股票、债券
    case credit = "信用"       // 信用卡、花呗、白条、月付
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .savings:
            return "banknote"
        case .virtual:
            return "iphone"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .credit:
            return "creditcard"
        }
    }
    
    var color: Color {
        switch self {
        case .savings:
            return .blue
        case .virtual:
            return .green
        case .investment:
            return .orange
        case .credit:
            return .red
        }
    }
}
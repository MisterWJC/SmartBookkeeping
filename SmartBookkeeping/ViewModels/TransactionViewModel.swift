//
//  TransactionViewModel.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import SwiftUI
import Combine
import CoreData
import UIKit

class TransactionViewModel: ObservableObject {
    @Published var rawInput: String = "" // Add this line
    @Published var transactions: [Transaction] = []
    @Published var currentMonthIncome: Double = 0.0
    @Published var currentMonthExpense: Double = 0.0
    
    // 当前月份的统计数据
    private var cancellables = Set<AnyCancellable>()
    
    private var viewContext: NSManagedObjectContext
    
    // 公开viewContext的访问方法
    var managedObjectContext: NSManagedObjectContext {
        return viewContext
    }
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        // 监听交易数据变化，更新统计信息
        $transactions
            .sink { [weak self] transactions in
                self?.updateStatistics(with: transactions)
            }
            .store(in: &cancellables)
        
        // 监听Core Data上下文变化，以便在快捷指令添加数据后自动刷新
        setupCoreDataNotifications()
        
        fetchTransactions() // 初始化时获取一次数据
    }
    
    deinit {
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupCoreDataNotifications() {
        // 监听Core Data保存通知
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 检查通知是否来自其他上下文（如快捷指令）
            if let context = notification.object as? NSManagedObjectContext,
               context != self.viewContext {
                print("检测到外部上下文数据变化，刷新交易数据")
                // 合并变化到当前上下文
                self.viewContext.mergeChanges(fromContextDidSave: notification)
                // 重新获取数据
                self.fetchTransactions()
            }
        }
        
        // 监听持久化存储远程变化通知
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("检测到持久化存储远程变化，刷新交易数据")
            self?.fetchTransactions()
        }
        
        // 监听应用从后台返回前台的通知
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("应用返回前台，刷新交易数据")
            self?.fetchTransactions()
        }
    }
    
    func updateStatistics(with transactions: [Transaction]) {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // 筛选当月交易
        let currentMonthTransactions = transactions.filter { transaction in
            let month = calendar.component(.month, from: transaction.date)
            let year = calendar.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear
        }
        
        // 计算收入和支出
        currentMonthIncome = currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        currentMonthExpense = currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    func addTransaction(_ transaction: Transaction) {
        let newTransaction = TransactionItem(context: viewContext)
        newTransaction.id = transaction.id
        newTransaction.amount = transaction.amount
        newTransaction.date = transaction.date
        newTransaction.category = transaction.category
        newTransaction.desc = transaction.description // 'description' is a reserved keyword
        newTransaction.type = transaction.type.rawValue
        newTransaction.paymentMethod = transaction.paymentMethod
        newTransaction.note = transaction.note
        newTransaction.timestamp = Date() // 设置创建时间戳
        
        saveContext()
        // 将新创建的 Transaction 对象添加到 transactions 数组的开头，以便立即在UI上反映
        let newDisplayTransaction = Transaction(
            id: newTransaction.id ?? UUID(),
            amount: newTransaction.amount,
            date: newTransaction.date ?? Date(),
            category: newTransaction.category ?? "",
            description: newTransaction.desc ?? "",
            type: Transaction.TransactionType(rawValue: newTransaction.type ?? "expense") ?? .expense,
            paymentMethod: newTransaction.paymentMethod ?? "",
            note: newTransaction.note ?? ""
        )
        // transactions.insert(newDisplayTransaction, at: 0) // 直接插入可能无法正确触发依赖此数组的视图更新
        fetchTransactions() // 重新获取数据以确保视图正确刷新
    }
    
    func fetchTransactions() {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionItem.date, ascending: false)]
        
        do {
            let results = try viewContext.fetch(request)
            transactions = results.map { entity in
                Transaction(id: entity.id ?? UUID(),
                            amount: entity.amount,
                            date: entity.date ?? Date(),
                            category: entity.category ?? "",
                            description: entity.desc ?? "", // Use 'desc' here
                            type: Transaction.TransactionType(rawValue: entity.type ?? "expense") ?? .expense,
                            paymentMethod: entity.paymentMethod ?? "",
                            note: entity.note ?? "")
            }
        } catch {
            print("获取交易数据失败: \(error.localizedDescription)")
        }
    }
    
    // 更新交易方法
    func updateTransaction(_ transaction: Transaction) {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(request)
            if let entityToUpdate = results.first {
                entityToUpdate.amount = transaction.amount
                entityToUpdate.date = transaction.date
                entityToUpdate.category = transaction.category
                entityToUpdate.desc = transaction.description
                entityToUpdate.type = transaction.type.rawValue
                entityToUpdate.paymentMethod = transaction.paymentMethod
                entityToUpdate.note = transaction.note
                // 注意：不更新timestamp，保持原始创建时间用于余额计算
                
                saveContext()
                fetchTransactions() // 更新后刷新列表
                print("交易更新成功，ID: \(transaction.id)")
            } else {
                print("未找到要更新的交易，ID: \(transaction.id)")
            }
        } catch {
            print("更新交易失败: \(error.localizedDescription)")
        }
    }
    
    // 修改 deleteTransaction 方法以接受 Transaction 对象
    func deleteTransaction(transaction: Transaction) {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        // 使用 transaction.id 来查找要删除的 TransactionItem
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(request)
            if let entityToDelete = results.first {
                viewContext.delete(entityToDelete)
                saveContext()
                fetchTransactions() // 删除后刷新列表
            } else {
                print("未找到要删除的交易，ID: \(transaction.id)")
            }
        } catch {
            print("删除交易失败: \(error.localizedDescription)")
        }
    }

    // 保留旧的 deleteTransaction(offsets: IndexSet) 方法，以防其他地方仍在使用
    // 或者根据实际情况决定是否移除或重构
    func deleteTransaction(offsets: IndexSet) {
        offsets.map { transactions[$0] }.forEach { transactionToDelete in
            // 调用新的删除方法
            deleteTransaction(transaction: transactionToDelete)
        }
        // 注意：saveContext() 和 fetchTransactions() 已经在新的 deleteTransaction(transaction:) 中调用
    }

    private func saveContext() {
        do {
            try viewContext.save()
            print("保存上下文成功！")
        } catch {
            let nsError = error as NSError
            fatalError("保存上下文未解决的错误 \(nsError), \(nsError.userInfo)")
        }
    }
    
    func getTransactionTypeDistribution(forMonth: String? = nil) -> [String: Double] {
        var distribution: [String: Double] = [
            "收入": 0,
            "支出": 0,
            // "转账": 0, // 根据实际需求决定是否包含转账
            // "投资": 0
        ]
        
        let filteredTransactions: [Transaction]
        if let month = forMonth, month != "全部月份" {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月"
            dateFormatter.locale = Locale(identifier: "zh_CN")
            
            filteredTransactions = transactions.filter {
                dateFormatter.string(from: $0.date) == month
            }
        } else {
            filteredTransactions = transactions
        }
        
        for transaction in filteredTransactions {
            if transaction.type == .income {
                distribution["收入"]? += transaction.amount
            } else if transaction.type == .expense {
                distribution["支出"]? += transaction.amount
            }
            // 根据需要添加对转账和投资的处理
        }
        
        return distribution
    }
    
    func getAllMonths() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月"
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        let months = Set(transactions.map { dateFormatter.string(from: $0.date) })
        return ["全部月份"] + Array(months).sorted().reversed() // reversed() 使最近的月份在前
    }
    
    func getMonthlyIncome(forMonth: String) -> Double {
        let filteredTransactions: [Transaction]
        if forMonth != "全部月份" {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月"
            dateFormatter.locale = Locale(identifier: "zh_CN")
            
            filteredTransactions = transactions.filter {
                dateFormatter.string(from: $0.date) == forMonth
            }
        } else {
            filteredTransactions = transactions
        }
        
        return filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyExpense(forMonth: String) -> Double {
        let filteredTransactions: [Transaction]
        if forMonth != "全部月份" {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月"
            dateFormatter.locale = Locale(identifier: "zh_CN")
            
            filteredTransactions = transactions.filter {
                dateFormatter.string(from: $0.date) == forMonth
            }
        } else {
            filteredTransactions = transactions
        }
        
        return filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
}

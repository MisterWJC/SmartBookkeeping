//
//  CategoryDataManager.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import CoreData
import Combine

class CategoryDataManager: ObservableObject {
    static let shared = CategoryDataManager()
    
    @Published var categoriesDidChange = false
    @Published var paymentMethodsDidChange = false
    
    private let context = PersistenceController.shared.container.viewContext
    
    private init() {
        initializeDefaultDataIfNeeded()
    }
    
    // 默认支出分类
    private let defaultExpenseCategories = ["数码电器", "餐饮美食", "自我提升", "服装饰品", "日用百货", "车辆交通", "娱乐休闲", "医疗健康", "家庭支出", "充值缴费", "其他"]
    
    // 默认收入分类
    private let defaultIncomeCategories = ["副业收入", "投资理财", "主业收入", "红包礼金", "其他收入"]
    
    // 默认支付方式
    private let defaultAccounts = [
        ("现金", "资产", "现金", 0.0),
        ("招商银行卡", "资产", "储蓄", 0.0),
        ("中信银行卡", "资产", "储蓄", 0.0),
        ("交通银行卡", "资产", "储蓄", 0.0),
        ("建设银行卡", "资产", "储蓄", 0.0),
        ("微信", "资产", "虚拟", 0.0),
        ("支付宝", "资产", "虚拟", 0.0),
        ("招商信用卡", "负债", "信用", 0.0)
    ]
    
    // 检查是否需要初始化默认数据
    private func initializeDefaultDataIfNeeded() {
        let userSettingsRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try context.fetch(userSettingsRequest)
            if userSettings.isEmpty {
                // 首次启动，创建默认数据
                createDefaultCategories()
                createDefaultAccounts()
                createUserSettings()
                try context.save()
            }
        } catch {
            print("初始化默认数据失败: \(error)")
        }
    }
    
    // 创建默认分类
    private func createDefaultCategories() {
        // 支出分类图标映射
        let expenseIcons = [
            "餐饮": "fork.knife",
            "交通": "car",
            "购物": "bag",
            "娱乐": "gamecontroller",
            "医疗": "cross.case",
            "教育": "book",
            "住房": "house",
            "通讯": "phone",
            "其他": "ellipsis.circle"
        ]
        
        // 收入分类图标映射
        let incomeIcons = [
            "工资": "briefcase",
            "奖金": "star",
            "投资": "chart.line.uptrend.xyaxis",
            "兼职": "person.2",
            "礼金": "gift",
            "其他": "plus.circle"
        ]
        
        // 创建支出分类
        for (index, category) in defaultExpenseCategories.enumerated() {
            let categoryItem = CategoryItem(context: context)
            categoryItem.id = UUID()
            categoryItem.name = category
            categoryItem.type = "expense"
            categoryItem.isDefault = true
            categoryItem.sortOrder = Int32(index)
            categoryItem.icon = expenseIcons[category] ?? "folder"
        }
        
        // 创建收入分类
        for (index, category) in defaultIncomeCategories.enumerated() {
            let categoryItem = CategoryItem(context: context)
            categoryItem.id = UUID()
            categoryItem.name = category
            categoryItem.type = "income"
            categoryItem.isDefault = true
            categoryItem.sortOrder = Int32(index)
            categoryItem.icon = incomeIcons[category] ?? "folder"
        }
    }
    
    // 创建默认账户
    private func createDefaultAccounts() {
        for (index, accountData) in defaultAccounts.enumerated() {
            let accountItem = AccountItem(context: context)
            accountItem.id = UUID()
            accountItem.name = accountData.0
            accountItem.accountType = accountData.1
            accountItem.accountCategory = accountData.2
            accountItem.initialBalance = accountData.3
            accountItem.balanceDate = Date()
            accountItem.includeInAssets = true
            accountItem.isDefault = true
            accountItem.note = ""
            accountItem.sortOrder = Int32(index)
        }
    }
    
    /// 初始化默认分类（公开方法）
    func initializeDefaultCategories() {
        // 检查是否已存在默认分类，避免重复创建
        let request: NSFetchRequest<CategoryItem> = CategoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == true")
        
        do {
            let existingCategories = try context.fetch(request)
            if existingCategories.isEmpty {
                createDefaultCategories()
                try context.save()
                categoriesDidChange = true
            } else {
                print("默认分类已存在，跳过创建")
            }
        } catch {
            print("初始化默认分类失败: \(error)")
        }
    }
    
    /// 初始化默认账户（公开方法）
    func initializeDefaultAccounts() {
        // 检查是否已存在默认账户，避免重复创建
        let request: NSFetchRequest<AccountItem> = AccountItem.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == true")
        
        do {
            let existingAccounts = try context.fetch(request)
            if existingAccounts.isEmpty {
                createDefaultAccounts()
                try context.save()
                paymentMethodsDidChange = true
            } else {
                print("默认账户已存在，跳过创建")
            }
        } catch {
            print("初始化默认账户失败: \(error)")
        }
    }
    
    // 创建用户设置
    private func createUserSettings() {
        let userSettings = UserSettings(context: context)
        userSettings.id = UUID()
        userSettings.hasCompletedInitialSetup = false
    }
    
    // 根据交易类型返回对应的分类列表
    func categories(for type: Transaction.TransactionType) -> [String] {
        let request: NSFetchRequest<CategoryItem> = CategoryItem.fetchRequest()
        let typeString = type == .income ? "income" : "expense"
        request.predicate = NSPredicate(format: "type == %@", typeString)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        do {
            let categoryItems = try context.fetch(request)
            let categoryNames = categoryItems.compactMap { $0.name }
            // 去重并保持顺序
            var uniqueCategories: [String] = []
            var seenCategories: Set<String> = []
            for category in categoryNames {
                if !seenCategories.contains(category) {
                    uniqueCategories.append(category)
                    seenCategories.insert(category)
                }
            }
            return uniqueCategories
        } catch {
            print("获取分类失败: \(error)")
            // 如果获取失败，返回默认分类
            return type == .income ? defaultIncomeCategories : defaultExpenseCategories
        }
    }
    
    // 添加新方法：获取分类列表（兼容旧接口）
    func getCategories(for type: Transaction.TransactionType) -> [String] {
        return categories(for: type)
    }
    
    // 返回支付方式列表（现在返回账户列表）
    func paymentMethods(for type: Transaction.TransactionType) -> [String] {
        let request: NSFetchRequest<AccountItem> = AccountItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        do {
            let accountItems = try context.fetch(request)
            let accountNames = accountItems.compactMap { $0.name }
            // 去重并保持顺序
            var uniqueAccounts: [String] = []
            var seenAccounts: Set<String> = []
            for account in accountNames {
                if !seenAccounts.contains(account) {
                    uniqueAccounts.append(account)
                    seenAccounts.insert(account)
                }
            }
            return uniqueAccounts
        } catch {
            print("获取账户失败: \(error)")
            // 如果获取失败，返回默认账户名称
            return defaultAccounts.map { $0.0 }
        }
    }
    
    // 返回默认账户数据
    var defaultAccountsData: [(String, String, String, Double)] {
        return defaultAccounts
    }
    
    // 返回所有支付方式（用于兼容性）
    var paymentMethods: [String] {
        return paymentMethods(for: .expense)
    }
    
    // 添加新分类
    func addCategory(name: String, icon: String, type: Transaction.TransactionType) {
        // 检查是否已存在同名分类
        let existingCategories = categories(for: type)
        if existingCategories.contains(name) {
            print("分类 '\(name)' 已存在，跳过添加")
            return
        }
        
        let categoryItem = CategoryItem(context: context)
        categoryItem.id = UUID()
        categoryItem.name = name
        categoryItem.type = type == .income ? "income" : "expense"
        categoryItem.isDefault = false
        categoryItem.icon = icon
        
        // 设置排序顺序为最后
        categoryItem.sortOrder = Int32(existingCategories.count)
        
        do {
            try context.save()
            // 通知数据变化
            DispatchQueue.main.async {
                self.categoriesDidChange.toggle()
            }
        } catch {
            print("添加分类失败: \(error)")
        }
    }
    
    // 添加新支付方式
    func addPaymentMethod(name: String) {
        let paymentMethodItem = PaymentMethodItem(context: context)
        paymentMethodItem.id = UUID()
        paymentMethodItem.name = name
        paymentMethodItem.type = "general"
        paymentMethodItem.isDefault = false
        
        // 设置排序顺序为最后
        let existingMethods = paymentMethods(for: .expense)
        paymentMethodItem.sortOrder = Int32(existingMethods.count)
        
        do {
            try context.save()
            // 通知数据变化
            DispatchQueue.main.async {
                self.paymentMethodsDidChange.toggle()
            }
        } catch {
            print("添加支付方式失败: \(error)")
        }
    }
    
    // 检查用户是否完成了初始设置
    func hasCompletedInitialSetup() -> Bool {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try context.fetch(request)
            return userSettings.first?.hasCompletedInitialSetup ?? false
        } catch {
            print("获取用户设置失败: \(error)")
            return false
        }
    }
    
    // 标记用户已完成初始设置
    func markInitialSetupCompleted() {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try context.fetch(request)
            if let settings = userSettings.first {
                settings.hasCompletedInitialSetup = true
                try context.save()
            }
        } catch {
            print("更新用户设置失败: \(error)")
        }
    }
}
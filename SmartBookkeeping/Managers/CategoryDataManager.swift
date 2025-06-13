//
//  CategoryDataManager.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import CoreData

class CategoryDataManager {
    static let shared = CategoryDataManager()
    
    private let context = PersistenceController.shared.container.viewContext
    
    private init() {
        initializeDefaultDataIfNeeded()
    }
    
    // 默认支出分类
    private let defaultExpenseCategories = ["数码电器", "餐饮美食", "自我提升", "服装饰品", "日用百货", "车辆交通", "娱乐休闲", "医疗健康", "家庭支出", "充值缴费", "其他"]
    
    // 默认收入分类
    private let defaultIncomeCategories = ["副业收入", "投资理财", "主业收入", "红包礼金", "其他收入"]
    
    // 默认支付方式
    private let defaultPaymentMethods = ["现金", "招商银行卡", "中信银行卡", "交通银行卡", "建设银行卡", "微信", "支付宝", "招商信用卡", "其他"]
    
    // 检查是否需要初始化默认数据
    private func initializeDefaultDataIfNeeded() {
        let userSettingsRequest: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let userSettings = try context.fetch(userSettingsRequest)
            if userSettings.isEmpty {
                // 首次启动，创建默认数据
                createDefaultCategories()
                createDefaultPaymentMethods()
                createUserSettings()
                try context.save()
            }
        } catch {
            print("初始化默认数据失败: \(error)")
        }
    }
    
    // 创建默认分类
    private func createDefaultCategories() {
        // 创建支出分类
        for (index, category) in defaultExpenseCategories.enumerated() {
            let categoryItem = CategoryItem(context: context)
            categoryItem.id = UUID()
            categoryItem.name = category
            categoryItem.type = "expense"
            categoryItem.isDefault = true
            categoryItem.sortOrder = Int32(index)
        }
        
        // 创建收入分类
        for (index, category) in defaultIncomeCategories.enumerated() {
            let categoryItem = CategoryItem(context: context)
            categoryItem.id = UUID()
            categoryItem.name = category
            categoryItem.type = "income"
            categoryItem.isDefault = true
            categoryItem.sortOrder = Int32(index)
        }
    }
    
    // 创建默认支付方式
    private func createDefaultPaymentMethods() {
        for (index, method) in defaultPaymentMethods.enumerated() {
            let paymentMethodItem = PaymentMethodItem(context: context)
            paymentMethodItem.id = UUID()
            paymentMethodItem.name = method
            paymentMethodItem.type = "general" // 通用支付方式
            paymentMethodItem.isDefault = true
            paymentMethodItem.sortOrder = Int32(index)
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
            return categoryItems.compactMap { $0.name }
        } catch {
            print("获取分类失败: \(error)")
            // 如果获取失败，返回默认分类
            return type == .income ? defaultIncomeCategories : defaultExpenseCategories
        }
    }
    
    // 返回支付方式列表
    func paymentMethods(for type: Transaction.TransactionType) -> [String] {
        let request: NSFetchRequest<PaymentMethodItem> = PaymentMethodItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        do {
            let paymentMethodItems = try context.fetch(request)
            return paymentMethodItems.compactMap { $0.name }
        } catch {
            print("获取支付方式失败: \(error)")
            // 如果获取失败，返回默认支付方式
            return defaultPaymentMethods
        }
    }
    
    // 返回所有支付方式（用于兼容性）
    var paymentMethods: [String] {
        return paymentMethods(for: .expense)
    }
    
    // 添加新分类
    func addCategory(name: String, type: Transaction.TransactionType) {
        let categoryItem = CategoryItem(context: context)
        categoryItem.id = UUID()
        categoryItem.name = name
        categoryItem.type = type == .income ? "income" : "expense"
        categoryItem.isDefault = false
        
        // 设置排序顺序为最后
        let existingCategories = categories(for: type)
        categoryItem.sortOrder = Int32(existingCategories.count)
        
        do {
            try context.save()
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
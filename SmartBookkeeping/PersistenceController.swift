//
//  PersistenceController.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/28.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SmartBookkeeping")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        // 配置持久化存储以支持远程通知
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // 配置视图上下文以自动合并变化
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 监听远程变化通知
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            print("检测到持久化存储远程变化")
        }
    }
    
    // Preview provider for SwiftUI previews
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Create 10 example transactions for the preview
        for i in 0..<10 {
            let newItem = TransactionItem(context: viewContext)
            newItem.timestamp = Date()
            newItem.amount = Double.random(in: 10...1000)
            newItem.category = ["餐饮美食", "日用百货", "交通出行", "工资收入"].randomElement()!
            newItem.desc = "示例交易 \(i)" // 修改 details 为 desc，与模型匹配
            newItem.id = UUID()
            newItem.note = "这是一条示例备注 \(i)"
            newItem.paymentMethod = ["微信", "支付宝", "银行卡"].randomElement()!
            // 注意：type 属性在模型中不存在，需要在 Xcode 中添加
            // newItem.type = i % 3 == 0 ? "income" : "expense"
            newItem.date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
}
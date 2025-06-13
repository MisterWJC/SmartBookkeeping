import SwiftUI
import UIKit
import CoreData

class ShortcutManager: ObservableObject {
    @Published var isProcessing = false
    @Published var processedData: Transaction?
    @Published var error: String?
    @Published var shouldShowEditForm = false
    @Published var editFormData: [String: String] = [:]
    
    func handleShortcutImage(_ imageData: Data) {
        isProcessing = true
        error = nil
        
        // 将图片数据转换为 UIImage
        guard let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.error = "无法处理图片数据"
                self.isProcessing = false
            }
            return
        }
        
        // 使用 OCR 服务识别图片
        let ocrService = OCRService()
        ocrService.recognizeText(from: image) { [weak self] transaction in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let transaction = transaction {
                    self.processedData = transaction
                    self.error = nil
                } else {
                    self.error = "无法识别账单信息"
                }
                
                self.isProcessing = false
            }
        }
    }
    
    private func saveTransaction(_ transaction: Transaction) {
        // 获取 Core Data 上下文
        let context = PersistenceController.shared.container.viewContext
        
        // 创建新的 TransactionItem
        let newTransaction = TransactionItem(context: context)
        newTransaction.id = UUID()
        newTransaction.amount = transaction.amount
        newTransaction.date = transaction.date
        newTransaction.desc = transaction.description
        newTransaction.category = transaction.category
        newTransaction.type = transaction.type.rawValue
        newTransaction.paymentMethod = transaction.paymentMethod
        newTransaction.note = transaction.note
        newTransaction.timestamp = Date()
        
        // 保存到 Core Data
        do {
            try context.save()
            print("通过URL Scheme识别的交易已保存到 Core Data")
        } catch {
            print("保存交易失败: \(error)")
            self.error = "保存失败: \(error.localizedDescription)"
        }
    }
    
    func handleEditURLData(_ data: [String: String]) {
        DispatchQueue.main.async {
            self.editFormData = data
            self.shouldShowEditForm = true
            print("接收到编辑数据: \(data)")
        }
    }
    
    func handleQuickEdit(transactionId: UUID) {
        print("开始处理快速编辑，交易ID: \(transactionId)")
        // 从 Core Data 中查找指定的交易
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transactionId as NSUUID)
        request.fetchLimit = 1
        
        print("执行Core Data查询...")
        
        do {
            let transactions = try context.fetch(request)
            print("查询结果数量: \(transactions.count)")
            
            if let transaction = transactions.first {
                print("找到交易记录: ID=\(transaction.id?.uuidString ?? "nil"), 金额=\(transaction.amount), 描述=\(transaction.desc ?? "无")")
                DispatchQueue.main.async {
                    // 将交易数据转换为编辑表单数据
                    self.editFormData = [
                        "transactionId": transactionId.uuidString,
                        "amount": String(transaction.amount),
                        "date": ISO8601DateFormatter().string(from: transaction.date ?? Date()),
                        "description": transaction.desc ?? "",
                        "category": transaction.category ?? "",
                        "type": transaction.type ?? "",
                        "paymentMethod": transaction.paymentMethod ?? "",
                        "note": transaction.note ?? ""
                    ]
                    self.shouldShowEditForm = true
                    print("快速编辑数据已加载: \(self.editFormData)")
                }
            } else {
                // 添加调试：查询所有交易记录的ID
                let allRequest: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
                if let allTransactions = try? context.fetch(allRequest) {
                    print("数据库中所有交易ID:")
                    for t in allTransactions {
                        print("  - \(t.id?.uuidString ?? "nil")")
                    }
                }
                
                DispatchQueue.main.async {
                    self.error = "未找到指定的交易记录"
                    print("未找到交易ID: \(transactionId)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "加载交易数据失败: \(error.localizedDescription)"
                print("查询交易失败: \(error)")
            }
        }
    }
    
    func reset() {
        isProcessing = false
        processedData = nil
        error = nil
        shouldShowEditForm = false
        editFormData = [:]
    }
}

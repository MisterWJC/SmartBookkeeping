import SwiftUI
import UIKit
import CoreData

class ShortcutManager: ObservableObject {
    @Published var isProcessing = false
    @Published var processedData: Transaction?
    @Published var error: String?
    
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
    
    func reset() {
        isProcessing = false
        processedData = nil
        error = nil
    }
}

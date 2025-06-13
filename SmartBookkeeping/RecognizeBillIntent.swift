//
//  RecognizeBillIntent.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import AppIntents
import SwiftUI
import UIKit
import CoreData

struct RecognizeBillIntent: AppIntent {
    static var title: LocalizedStringResource = "识别账单"
    static var description: IntentDescription = IntentDescription(
        "识别账单图片并自动记账",
        categoryName: "记账",
        searchKeywords: ["账单", "记账", "扫描", "OCR", "智能记账"]
    )
    
    @Parameter(
        title: "账单图片",
        description: "需要识别的账单图片",
        supportedTypeIdentifiers: ["public.image"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var billImage: IntentFile?
    
    @MainActor
    func perform() async throws -> IntentResultContainer<String, Never, Never, Never> {
        // 检查是否有图片输入
        guard let billImage = billImage else {
            return .result(value: "请提供账单图片")
        }
        
        // 读取图片数据
        guard let imageData = try? await billImage.data(contentType: .image) else {
            return .result(value: "无法读取图片数据")
        }
        
        // 将图片数据转换为 UIImage
        guard let image = UIImage(data: imageData) else {
            return .result(value: "无法处理图片数据")
        }
        
        // 添加打印语句观察 OCR 识别的文本
        print("=== 快捷指令 OCR 识别调试信息 ===")
        print("图片数据大小: \(imageData.count) bytes")
        print("图片尺寸: \(image.size)")
        print("图片方向: \(image.imageOrientation.rawValue)")
        print("图片比例: \(image.scale)")
        
        // 使用 OCR 服务识别图片
        let ocrService = OCRService()
        let transaction = await withCheckedContinuation { continuation in
            ocrService.recognizeText(from: image) { result in
                continuation.resume(returning: result)
            }
        }
        
        guard let recognizedTransaction = transaction else {
            return .result(value: "识别失败：无法从图片中提取账单信息")
        }
        
        // 保存到 Core Data
        let context = PersistenceController.shared.container.viewContext
        let newTransaction = TransactionItem(context: context)
        let transactionId = UUID()
        newTransaction.id = transactionId
        newTransaction.amount = recognizedTransaction.amount
        newTransaction.date = recognizedTransaction.date
        newTransaction.desc = recognizedTransaction.description
        newTransaction.category = recognizedTransaction.category
        newTransaction.type = recognizedTransaction.type.rawValue
        newTransaction.paymentMethod = recognizedTransaction.paymentMethod
        newTransaction.note = recognizedTransaction.note
        newTransaction.timestamp = Date()
        
        do {
            try context.save()
            let resultMessage = formatTransactionResult(recognizedTransaction, transactionId: transactionId)
            return .result(value: resultMessage)
        } catch {
            return .result(value: "保存失败：\(error.localizedDescription)")
        }
    }
    
    private func saveTransaction(_ data: TransactionData) {
        // 获取 Core Data 上下文
        let context = PersistenceController.shared.container.viewContext
        
        // 创建新的 TransactionItem
        let newTransaction = TransactionItem(context: context)
        newTransaction.id = UUID()
        newTransaction.amount = data.amount
        newTransaction.date = data.date
        newTransaction.desc = data.note // 使用 note 作为描述
        newTransaction.category = data.category
        newTransaction.type = data.type.rawValue
        newTransaction.paymentMethod = "未指定" // TransactionData 中没有支付方式，使用默认值
        newTransaction.note = "通过快捷指令添加" // 添加备注说明来源
        
        // 保存到 Core Data
        do {
            try context.save()
            print("交易已保存到 Core Data")
        } catch {
            print("保存交易失败: \(error)")
        }
    }
    
    private func saveTransactionFromOCR(_ transaction: Transaction) {
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
        newTransaction.timestamp = Date() // 添加时间戳
        
        // 保存到 Core Data
        do {
            try context.save()
            print("OCR 识别的交易已保存到 Core Data")
        } catch {
            print("保存 OCR 交易失败: \(error)")
        }
    }
    
    private func formatTransactionResult(_ transaction: Transaction, transactionId: UUID) -> String {
        var result = "✅ 账单识别成功！\n\n"
        result += "💰 金额：¥\(String(format: "%.2f", transaction.amount))\n"
        result += "📅 日期：\(DateFormatter.localizedString(from: transaction.date, dateStyle: .medium, timeStyle: .none))\n"
        result += "📝 描述：\(transaction.description)\n"
        result += "🏷️ 类别：\(transaction.category)\n"
        result += "💳 支付方式：\(transaction.paymentMethod)\n"
        result += "📋 类型：\(transaction.type.rawValue)\n"
        
        if !transaction.note.isEmpty {
            result += "📄 备注：\(transaction.note)\n"
        }
        
        result += "\n✨ 已自动保存到记账本\n"
        result += "\n❓ 信息是否准确？如需修改请选择编辑修改\n"
        result += "\n🔗 编辑链接：smartbookkeeping://edit?transactionId=\(transactionId.uuidString)&action=quickEdit"
        return result
    }
 
}
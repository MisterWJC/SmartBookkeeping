//
//  TransactionFormViewModel.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI
import Combine
import AVFoundation
import CoreData

// MARK: - Supporting Types for State Management

/// Represents the data currently entered in the form.
struct TransactionFormData {
    var amount: String = ""
    var date: Date = Date()
    var description: String = ""
    var category: String = CategoryDataManager.shared.expenseCategories.first ?? "其他"
    var type: Transaction.TransactionType = .expense
    var paymentMethod: String = CategoryDataManager.shared.paymentMethods.first ?? "现金"
    var note: String = ""
    var image: UIImage? = nil
}

/// Enum to manage which sheet is currently presented.
enum ActiveSheet: Identifiable {
    case imagePicker, camera, csvImport, manualInput
    
    var id: Int { hashValue }
}

/// Enum to manage which alert is shown.
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - TransactionFormViewModel

@MainActor
final class TransactionFormViewModel: ObservableObject {
    // MARK: Properties
    
    // Form data state
    @Published var formData = TransactionFormData()
    
    // UI presentation state
    @Published var activeSheet: ActiveSheet?
    @Published var alertItem: AlertItem?
    
    // Input module state
    @Published var quickInputText: String = ""
    @Published var inputMode: TransactionFormView.InputMode = .text
    @Published var showExtraButtons: Bool = false
    
    // Processing state
    @Published var isProcessing: Bool = false
    @Published var isRecording: Bool = false
    @Published var isProcessingAI: Bool = false  // 新增：跟踪AI处理状态
    var recordingStartTime: Date? = nil
    
    // Dependencies
    private let _context: NSManagedObjectContext
    
    var context: NSManagedObjectContext {
        _context
    }
    private let ocrService = OCRService()
    private let speechService = SpeechRecognitionService()
    // Other dependencies like AIService, ShortcutManager would be injected or accessed here.
    
    // Callback to refresh transaction data
    var onTransactionSaved: (() -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Data sources for pickers
    // Note: These would come from a model or service in a real app, like OCRService.
    
    init(context: NSManagedObjectContext) {
        self._context = context
        setupSpeechRecognitionSinks()
    }
    
    // MARK: - Computed Properties for View
    
    var categoriesForSelectedType: [String] {
        return CategoryDataManager.shared.categories(for: formData.type)
    }
    
    var paymentMethodsForSelectedType: [String] {
        return CategoryDataManager.shared.paymentMethods
    }
    
    // MARK: - Intents (User Actions)
    
    func changeInputMode(to mode: TransactionFormView.InputMode) {
        inputMode = mode
        if mode == .voice {
            quickInputText = ""
        }
    }
    
    func updateCategoryForType(_ type: Transaction.TransactionType) {
        let categories = CategoryDataManager.shared.categories(for: type)
        if let firstCategory = categories.first {
            formData.category = firstCategory
        }
    }
    
    func toggleExtraButtons() {
        showExtraButtons.toggle()
        // Resign first responder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func presentSheet(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image else { return }
        
        // 检查是否正在处理AI请求，防止重复调用
        if isProcessingAI {
            alertItem = AlertItem(title: "处理中", message: "正在处理中，请稍候...")
            return
        }
        
        formData.image = image
        isProcessing = true
        isProcessingAI = true  // 设置AI处理状态
        
        // Encapsulate OCR and AI processing
        ocrService.recognizeText(from: image) { [weak self] ocrTransaction in
            guard let self = self else { return }
            
            // Simplified logic: Directly apply OCR results.
            // AI processing logic would be called here.
            DispatchQueue.main.async {
                self.isProcessing = false
                self.isProcessingAI = false  // 重置AI处理状态
                if let transaction = ocrTransaction {
                    self.updateForm(with: transaction)
                    self.alertItem = AlertItem(title: "识别成功", message: "已自动识别，请核对后保存。")
                } else {
                    self.alertItem = AlertItem(title: "识别失败", message: "无法识别图片内容，请手动输入。")
                }
            }
        }
    }
    
    func processQuickInput() {
        guard !quickInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertItem = AlertItem(title: "输入为空", message: "请输入账单信息")
            return
        }
        
        // 检查是否正在处理AI请求，防止重复调用
        if isProcessingAI {
            alertItem = AlertItem(title: "处理中", message: "正在处理中，请稍候...")
            return
        }
        
        isProcessing = true
        isProcessingAI = true  // 设置AI处理状态
        
        // 调用 AIService 处理手动输入的文本
        AIService.shared.processText(quickInputText) { [weak self] aiResponse in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let response = aiResponse {
                    // 使用 BillProcessingService 处理 AI 响应
                    if let transaction = BillProcessingService.shared.processAIResponse(response) {
                        // 更新表单
                        self.updateForm(with: transaction)
                        self.alertItem = AlertItem(title: "识别成功", message: "已自动识别，请核对后保存。")
                    } else {
                        // AI 响应处理失败，创建一个基本的 Transaction 对象
                        let transaction = Transaction(
                            amount: 0.0,
                            date: Date(),
                            category: "未分类",
                            description: self.quickInputText,
                            type: .expense,
                            paymentMethod: "未知",
                            note: ""
                        )
                        self.updateForm(with: transaction)
                        self.alertItem = AlertItem(title: "识别失败", message: "AI 响应处理失败，请手动填写。")
                    }
                } else {
                    // 识别失败，创建一个基本的 Transaction 对象
                    let transaction = Transaction(
                        amount: 0.0,
                        date: Date(),
                        category: "未分类",
                        description: self.quickInputText,
                        type: .expense,
                        paymentMethod: "未知",
                        note: ""
                    )
                    self.updateForm(with: transaction)
                    self.alertItem = AlertItem(title: "识别失败", message: "无法识别账单信息，请手动填写。")
                }
                
                // 不再自动关闭手动输入页面，让用户决定何时关闭
                self.isProcessing = false
                self.isProcessingAI = false  // 重置AI处理状态
                // 保留输入文本，方便用户进一步编辑
            }
        }
    }

    func saveTransaction() {
        guard let amountValue = Double(formData.amount), amountValue != 0 else {
            alertItem = AlertItem(title: "错误", message: "请输入有效的金额。")
            return
        }
        
        let newTransaction = Transaction(
            amount: abs(amountValue),
            date: formData.date,
            category: formData.category,
            description: formData.description,
            type: formData.type,
            paymentMethod: formData.paymentMethod,
            note: formData.note
        )
        
        // Logic to add to Core Data context
        let transactionItem = TransactionItem(context: context)
        transactionItem.id = UUID() // Assuming your TransactionItem has an id
        transactionItem.amount = newTransaction.amount
        transactionItem.date = newTransaction.date
        transactionItem.category = newTransaction.category
        transactionItem.desc = newTransaction.description // Ensure 'desc' matches your Core Data attribute name
        transactionItem.type = newTransaction.type.rawValue // Assuming 'type' is a String in Core Data
        transactionItem.paymentMethod = newTransaction.paymentMethod
        transactionItem.note = newTransaction.note
        // Add any other properties from newTransaction to transactionItem

        do {
            try context.save()
            print("Transaction saved successfully: \(newTransaction.description) - \(newTransaction.amount)")
            resetForm()
            alertItem = AlertItem(title: "成功", message: "账单已保存。")
            // Notify that transaction was saved
            onTransactionSaved?()
        } catch {
            // Handle the error appropriately
            let nsError = error as NSError
            print("Error saving transaction: \(nsError), \(nsError.userInfo)")
            alertItem = AlertItem(title: "保存失败", message: "保存账单时发生错误: \(nsError.localizedDescription)")
        }
    }
    
    func resetForm() {
        formData = TransactionFormData()
        // TransactionFormData已经设置了正确的默认值，无需额外设置
    }
    
    // MARK: - Voice Input Handling
    
    private func setupSpeechRecognitionSinks() {
        speechService.$recognizedText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .assign(to: &$quickInputText)

        speechService.$error
            .compactMap { $0 }
            .map { AlertItem(title: "语音识别错误", message: $0) }
            .assign(to: &$alertItem)
    }
    
    func startVoiceRecording() {
        do {
            recordingStartTime = Date()
            isRecording = true
            try speechService.startRecording()
        } catch {
            alertItem = AlertItem(title: "录音错误", message: error.localizedDescription)
            isRecording = false
            recordingStartTime = nil
        }
    }
    
    func stopVoiceRecordingAndProcess() {
        speechService.stopRecording()
        isRecording = false
        recordingStartTime = nil
        
        // Only show manual input if we have recognized text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.quickInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.presentSheet(.manualInput)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// A single function to update the form from any data source (OCR, AI, Shortcut).
    /// A single function to update the form from any data source (OCR, AI, Shortcut).
    /// Note: The 'TransactionInput' type here is a placeholder for the actual structure
    /// expected from OCR/AI services. It should be defined elsewhere in your project.
    /// For now, we'll assume it has properties similar to 'Transaction'.
    private func updateForm(with data: Transaction) {
        formData.amount = String(format: "%.2f", data.amount)
        formData.date = data.date
        formData.description = data.description
        formData.type = data.type
        formData.note = data.note
        
        // Safely set category with fuzzy matching
        let categories = categoriesForSelectedType
        if categories.contains(data.category) {
            formData.category = data.category
        } else {
            // Try fuzzy matching for AI returned categories
            let bestMatch = findBestCategoryMatch(aiCategory: data.category, availableCategories: categories)
            formData.category = bestMatch ?? categories.first ?? "未分类"
        }
        
        // Safely set payment method
        let methods = paymentMethodsForSelectedType
        if methods.contains(data.paymentMethod) {
            formData.paymentMethod = data.paymentMethod
        } else {
            formData.paymentMethod = methods.first ?? "未知"
        }
    }

    // Add fuzzy matching helper method
    private func findBestCategoryMatch(aiCategory: String, availableCategories: [String]) -> String? {
        let categoryMappings: [String: String] = [
            "餐饮": "餐饮美食",
            "美食": "餐饮美食",
            "数码": "数码电器",
            "电器": "数码电器",
            "服装": "服装饰品",
            "饰品": "服装饰品",
            "交通": "车辆交通",
            "车辆": "车辆交通",
            "娱乐": "娱乐休闲",
            "休闲": "娱乐休闲",
            "医疗": "医疗健康",
            "健康": "医疗健康",
            "家庭": "家庭支出",
            "充值": "充值缴费",
            "缴费": "充值缴费"
        ]
        
        // Direct mapping
        if let mappedCategory = categoryMappings[aiCategory] {
            return mappedCategory
        }
        
        // Partial matching
        for category in availableCategories {
            if category.contains(aiCategory) || aiCategory.contains(category) {
                return category
            }
        }
        
        return nil
    }
}
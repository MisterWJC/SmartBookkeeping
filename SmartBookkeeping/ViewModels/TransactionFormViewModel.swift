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
    let type: AlertType
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    
    init(title: String, message: String, type: AlertType = .info, primaryAction: (() -> Void)? = nil, secondaryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.type = type
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

/// Enum to define different types of alerts
enum AlertType {
    case info           // 普通信息提示
    case confirmation   // 需要确认的操作
    case error          // 错误提示
    case processing     // 处理中状态
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
    
    // Edit mode state
    @Published var isEditMode: Bool = false
    @Published var editingTransactionId: String? = nil
    
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
    
    // MARK: - URL Data Handling
    
    func populateFromURLData(_ data: [String: String]) {
        // 检查是否为编辑模式
        if let transactionIdString = data["transactionId"], let _ = UUID(uuidString: transactionIdString) {
            editingTransactionId = transactionIdString
            isEditMode = true
            print("进入编辑模式，交易ID: \(transactionIdString)")
        }
        
        // 先处理交易类型，因为分类验证依赖于类型
        var targetType = formData.type // 默认使用当前类型
        if let typeStr = data["type"], let type = Transaction.TransactionType(rawValue: typeStr) {
            targetType = type
            formData.type = type
        }
        
        // 解析并填充表单数据
        if let amountStr = data["amount"], let amount = Double(amountStr) {
            formData.amount = String(format: "%.2f", amount)
        }
        
        if let dateStr = data["date"] {
            // 尝试ISO8601格式
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateStr) {
                formData.date = date
            } else {
                // 回退到原有格式
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                if let date = dateFormatter.date(from: dateStr) {
                    formData.date = date
                }
            }
        }
        
        if let description = data["description"] {
            formData.description = description
        }
        
        // 处理分类，基于最终确定的交易类型进行验证
        if let category = data["category"] {
            // 验证分类是否在目标交易类型的有效分类列表中
            let validCategories = CategoryDataManager.shared.categories(for: targetType)
            if validCategories.contains(category) {
                formData.category = category
                print("分类 '\(category)' 验证通过，已设置")
            } else {
                // 如果分类无效，尝试使用相似度匹配
                if let bestMatch = findBestCategoryMatch(category, for: targetType) {
                    formData.category = bestMatch
                    print("分类 '\(category)' 不完全匹配，使用最佳匹配: '\(bestMatch)'")
                } else {
                    // 如果没有好的匹配，设置为默认分类
                    let defaultCategory = targetType == .income ? "其他收入" : "其他"
                    formData.category = defaultCategory
                    print("分类 '\(category)' 不在有效分类列表中，已设置为'\(defaultCategory)'")
                }
            }
        } else {
            // 如果没有提供分类，且交易类型发生了变化，则更新为该类型的默认分类
            if targetType != formData.type {
                updateCategoryForType(targetType)
            }
        }
        
        if let paymentMethod = data["paymentMethod"] {
            formData.paymentMethod = paymentMethod
        }
        
        if let note = data["note"] {
            formData.note = note
        }
        
        print("表单数据已从 URL 参数填充: \(data)")
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
    
    // 使用相似度匹配找到最佳分类
    private func findBestCategoryMatch(_ inputCategory: String, for type: Transaction.TransactionType) -> String? {
        let validCategories = CategoryDataManager.shared.categories(for: type)
        
        // 首先尝试精确匹配（忽略大小写）
        if let exactMatch = validCategories.first(where: { $0.lowercased() == inputCategory.lowercased() }) {
            return exactMatch
        }
        
        // 然后尝试包含匹配
        if let containsMatch = validCategories.first(where: { $0.contains(inputCategory) || inputCategory.contains($0) }) {
            return containsMatch
        }
        
        // 最后使用Jaro-Winkler相似度匹配
        var bestMatch: String?
        var bestSimilarity: Double = 0.6 // 设置阈值
        
        for category in validCategories {
            let similarity = jaroWinklerSimilarity(inputCategory, category)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestMatch = category
            }
        }
        
        return bestMatch
    }
    
    // Jaro-Winkler相似度计算
    private func jaroWinklerSimilarity(_ s1: String, _ s2: String) -> Double {
        let jaroSim = jaroSimilarity(s1, s2)
        if jaroSim < 0.7 { return jaroSim }
        
        let prefixLength = min(4, commonPrefixLength(s1, s2))
        return jaroSim + (0.1 * Double(prefixLength) * (1.0 - jaroSim))
    }
    
    private func jaroSimilarity(_ s1: String, _ s2: String) -> Double {
        let len1 = s1.count
        let len2 = s2.count
        
        if len1 == 0 && len2 == 0 { return 1.0 }
        if len1 == 0 || len2 == 0 { return 0.0 }
        
        let matchWindow = max(len1, len2) / 2 - 1
        if matchWindow < 0 { return 0.0 }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        var s1Matches = Array(repeating: false, count: len1)
        var s2Matches = Array(repeating: false, count: len2)
        
        var matches = 0
        
        // 找到匹配的字符
        for i in 0..<len1 {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, len2)
            
            for j in start..<end {
                if s2Matches[j] || s1Array[i] != s2Array[j] { continue }
                s1Matches[i] = true
                s2Matches[j] = true
                matches += 1
                break
            }
        }
        
        if matches == 0 { return 0.0 }
        
        // 计算转置
        var transpositions = 0
        var k = 0
        for i in 0..<len1 {
            if !s1Matches[i] { continue }
            while !s2Matches[k] { k += 1 }
            if s1Array[i] != s2Array[k] { transpositions += 1 }
            k += 1
        }
        
        return (Double(matches) / Double(len1) + Double(matches) / Double(len2) + Double(matches - transpositions/2) / Double(matches)) / 3.0
    }
    
    private func commonPrefixLength(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let minLength = min(s1Array.count, s2Array.count)
        
        for i in 0..<minLength {
            if s1Array[i] != s2Array[i] {
                return i
            }
        }
        return minLength
    }
    
    func toggleExtraButtons() {
        showExtraButtons.toggle()
        // Resign first responder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func presentSheet(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }
    
    func showImageConfirmation(for image: UIImage, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        alertItem = AlertItem(
            title: "确认使用此图片？",
            message: "请确认是否使用选择的图片进行识别",
            type: .confirmation,
            primaryAction: onConfirm,
            secondaryAction: onCancel
        )
    }
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image else { return }
        
        // 检查是否正在处理AI请求，防止重复调用
        if isProcessingAI {
            print("AI正在处理中，显示警告")
            alertItem = AlertItem(title: "处理中", message: "正在处理中，请稍候...", type: .processing)
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
                    self.alertItem = AlertItem(title: "识别成功", message: "已自动识别，请核对后保存。", type: .info)
            } else {
                self.alertItem = AlertItem(title: "识别失败", message: "无法识别图片内容，请手动输入。", type: .error)
                }
            }
        }
    }
    
    func processQuickInput() {
        guard !quickInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertItem = AlertItem(title: "输入为空", message: "请输入账单信息", type: .error)
            return
        }
        
        // 检查是否正在处理AI请求，防止重复调用
        if isProcessingAI {
            alertItem = AlertItem(title: "处理中", message: "正在处理中，请稍候...", type: .processing)
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
                        self.alertItem = AlertItem(title: "识别成功", message: "已自动识别，请核对后保存。", type: .info)
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
                        self.alertItem = AlertItem(title: "识别失败", message: "AI 响应处理失败，请手动填写。", type: .error)
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
                    self.alertItem = AlertItem(title: "识别失败", message: "无法识别账单信息，请手动填写。", type: .error)
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
            alertItem = AlertItem(title: "错误", message: "请输入有效的金额。", type: .error)
            return
        }
        
        let transactionData = Transaction(
            amount: abs(amountValue),
            date: formData.date,
            category: formData.category,
            description: formData.description,
            type: formData.type,
            paymentMethod: formData.paymentMethod,
            note: formData.note
        )
        
        do {
            if isEditMode, let editingId = editingTransactionId, let transactionId = UUID(uuidString: editingId) {
                // 编辑模式：更新现有交易
                let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", transactionId as CVarArg)
                request.fetchLimit = 1
                
                let transactions = try context.fetch(request)
                if let existingTransaction = transactions.first {
                    // 更新现有交易的数据
                    existingTransaction.amount = transactionData.amount
                    existingTransaction.date = transactionData.date
                    existingTransaction.category = transactionData.category
                    existingTransaction.desc = transactionData.description
                    existingTransaction.type = transactionData.type.rawValue
                    existingTransaction.paymentMethod = transactionData.paymentMethod
                    existingTransaction.note = transactionData.note
                    existingTransaction.timestamp = Date() // 更新修改时间
                    
                    try context.save()
                    print("Transaction updated successfully: \(transactionData.description) - \(transactionData.amount)")
                    resetForm()
                    alertItem = AlertItem(title: "成功", message: "账单已更新。", type: .info)
                } else {
                    alertItem = AlertItem(title: "错误", message: "未找到要编辑的交易记录。", type: .error)
                    return
                }
            } else {
                // 新增模式：创建新交易
                let transactionItem = TransactionItem(context: context)
                transactionItem.id = UUID()
                transactionItem.amount = transactionData.amount
                transactionItem.date = transactionData.date
                transactionItem.category = transactionData.category
                transactionItem.desc = transactionData.description
                transactionItem.type = transactionData.type.rawValue
                transactionItem.paymentMethod = transactionData.paymentMethod
                transactionItem.note = transactionData.note
                transactionItem.timestamp = Date()
                
                try context.save()
                print("Transaction saved successfully: \(transactionData.description) - \(transactionData.amount)")
                resetForm()
                alertItem = AlertItem(title: "成功", message: "账单已保存。", type: .info)
            }
            
            // Notify that transaction was saved
            onTransactionSaved?()
        } catch {
            // Handle the error appropriately
            let nsError = error as NSError
            print("Error saving transaction: \(nsError), \(nsError.userInfo)")
            let action = isEditMode ? "更新" : "保存"
            alertItem = AlertItem(title: "\(action)失败", message: "\(action)账单时发生错误: \(nsError.localizedDescription)", type: .error)
        }
    }
    
    func resetForm() {
        formData = TransactionFormData()
        // 重置编辑模式状态
        isEditMode = false
        editingTransactionId = nil
        // TransactionFormData已经设置了正确的默认值，无需额外设置
    }
    
    // MARK: - Voice Input Handling
    
    private func setupSpeechRecognitionSinks() {
        speechService.$recognizedText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .assign(to: &$quickInputText)

        speechService.$error
            .compactMap { $0 }
            .map { AlertItem(title: "语音识别错误", message: $0, type: .error) }
            .assign(to: &$alertItem)
    }
    
    func startVoiceRecording() {
        do {
            recordingStartTime = Date()
            isRecording = true
            try speechService.startRecording()
        } catch {
            alertItem = AlertItem(title: "录音错误", message: error.localizedDescription, type: .error)
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
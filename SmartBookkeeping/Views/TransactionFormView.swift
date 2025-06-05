//
//  TransactionFormView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

enum FormField: Hashable {
    case amount, description, note
}

struct TransactionFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shortcutManager: ShortcutManager
    
    @ObservedObject var viewModel: TransactionViewModel
    @FocusState private var focusedField: FormField?
    
    // 表单数据
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var description: String = ""
    @State private var category: String = "请选择分类"
    @State private var selectedType: Transaction.TransactionType = .expense
    @State private var paymentMethod: String = "请选择"
    @State private var note: String = ""
    
    // 图片相关状态
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var inputImage: UIImage?
    @State private var showingCamera = false
    @State private var showingOCR = false
    @State private var showingShortcutProcessing = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    // OCR 相关状态
    @State private var showOcrSuccessAlert = false
    @State private var showOcrFailureAlert = false
    @State private var isOpenedViaShortcuts = false
    private let ocrService = OCRService()
    
    // 按钮反馈状态
    @State private var saveButtonPressed = false
    @State private var resetButtonPressed = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                Form {
                    amountSection
                    dateSection
                    typeSection
                    categorySection
                    descriptionSection
                    paymentMethodSection
                    noteSection
                    actionButtonsSection
                    recentTransactionsSection
                    shortcutProcessingSection
                }
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = nil
                        }
                )
                .navigationTitle("智能记账助手")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("上传数据") {
                            showingActionSheet = true
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完成") {
                            focusedField = nil
                        }
                    }
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("选择图像来源"), buttons: [
                .default(Text("从相册选择")) { showingImagePicker = true },
                .default(Text("从文件选择器选择")) { showingImagePicker = true },
                .default(Text("加载 alipay_1.jpeg")) { loadTestImage(name: "alipay_1.jpeg") },
                .default(Text("加载 alipay_2.png")) { loadTestImage(name: "alipay_2.png") },
                .default(Text("加载 alipay_3.PNG")) { loadTestImage(name: "alipay_3.PNG") },
                .default(Text("加载 wechat_pay1.jpg")) { loadTestImage(name: "wechat_pay1.jpg") },
                .default(Text("加载 wechat_pay2.png")) { loadTestImage(name: "wechat_pay2.png") },
                .default(Text("加载 wechat_pay3.PNG")) { loadTestImage(name: "wechat_pay3.PNG") },
                .default(Text("加载 yunshanfu1.jpg")) { loadTestImage(name: "yunshanfu1.jpg") },
                .default(Text("加载 yunshanfu2.png")) { loadTestImage(name: "yunshanfu2.png") },
                .default(Text("加载 Douyin_1.jpg")) { loadTestImage(name: "Douyin_1.jpg") },
                .cancel()
            ])
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .onChange(of: inputImage) { oldValue, newValue in
            handleImageSelection(newValue)
        }
        .alert("识别成功", isPresented: $showOcrSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("已自动识别，请核对后保存")
        }
        .alert("识别失败", isPresented: $showOcrFailureAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("无法识别图片内容，请手动输入")
        }
        .onOpenURL { url in
            // url 就是图片的本地文件 URL
            print("收到的文件 URL: \(url)")
            if let imageData = try? Data(contentsOf: url), let image = UIImage(data: imageData) {
                // 这里可以直接传递给你的 OCR/AI 处理逻辑
                shortcutManager.handleShortcutImage(imageData)
                // 或者直接赋值到 inputImage 以便 UI 展示
                // self.inputImage = image
            } else {
                print("无法读取图片数据，路径：\(url)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShortcutImageReceived"))) { notification in
            handleShortcutImageReceived(notification)
        }
        .onChange(of: shortcutManager.processedData) { oldValue, newValue in
            if newValue != nil {
                showingShortcutProcessing = true
            }
        }
        .alert("快捷指令处理完成", isPresented: $showingShortcutProcessing) {
            Button("确定") {
                showingShortcutProcessing = false
            }
        } message: {
            Text("数据已处理完成，请检查并确认。")
        }
    }
    
    // MARK: - Subviews
    
    private var amountSection: some View {
        Section(header: Text("金额")) {
            TextField("请输入金额", text: $amount)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
        }
    }
    
    private var dateSection: some View {
        Section(header: Text("交易日期")) {
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
        }
    }
    
    private var typeSection: some View {
        Section(header: Text("收/支类型")) {
            Picker("请选择", selection: $selectedType) {
                ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var categorySection: some View {
        Section(header: Text("交易分类")) {
            Picker("请选择分类", selection: $category) {
                ForEach(viewModel.categories(for: selectedType), id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedType) { oldValue, newValue in
                if !viewModel.categories(for: newValue).contains(category) {
                    category = viewModel.categories(for: newValue).first ?? ""
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        Section(header: Text("商品明细")) {
            TextField("例：超市购物/餐饮消费", text: $description)
                .keyboardType(.default)
                .focused($focusedField, equals: .description)
        }
    }
    
    private var paymentMethodSection: some View {
        Section(header: Text("付款/收款方式")) {
            Picker("请选择", selection: $paymentMethod) {
                ForEach(viewModel.paymentMethods(for: selectedType), id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedType) { oldValue, newValue in
                if !viewModel.paymentMethods(for: newValue).contains(paymentMethod) {
                    paymentMethod = viewModel.paymentMethods(for: newValue).first ?? ""
                }
            }
        }
    }
    
    private var noteSection: some View {
        Section(header: Text("备注")) {
            TextEditor(text: $note)
                .frame(height: 100)
                .focused($focusedField, equals: .note)
        }
    }
    
    private var actionButtonsSection: some View {
        Section {
            Button(action: {
                DispatchQueue.main.async {
                    saveButtonPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    saveButtonPressed = false
                }
                saveTransaction()
            }) {
                Text("保存")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(saveButtonPressed ? Color.green.opacity(0.7) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .listRowInsets(EdgeInsets())
            
            Button(action: {
                DispatchQueue.main.async {
                    resetButtonPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    resetButtonPressed = false
                }
                resetForm()
            }) {
                Text("重置")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(resetButtonPressed ? Color.orange.opacity(0.7) : Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }
            .listRowInsets(EdgeInsets())
        }
    }
    
    private var recentTransactionsSection: some View {
        Section {
            Text("最近账单")
                .font(.headline)
            
            if viewModel.transactions.isEmpty {
                Text("暂无账单记录。")
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(viewModel.transactions.prefix(3)) { transaction in
                        TransactionRowView(transaction: transaction)
                    }
                }
                .frame(height: 70)
            }
        }
    }
    
    private var shortcutProcessingSection: some View {
        Group {
            if shortcutManager.isProcessing {
                Section {
                    HStack {
                        ProgressView()
                        Text("正在处理快捷指令数据...")
                    }
                }
            }
            
            if let error = shortcutManager.error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            if let processedData = shortcutManager.processedData {
                Section("快捷指令识别结果") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("金额: \(processedData.amount, specifier: "%.2f")")
                        Text("类别: \(processedData.category)")
                        Text("日期: \(processedData.date.formatted())")
                        Text("备注: \(processedData.note)")
                        Text("类型: \(processedData.type == .expense ? "支出" : "收入")")
                    }
                    
                    Button("应用识别结果") {
                        applyProcessedData(processedData)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleImageSelection(_ image: UIImage?) {
        guard let selectedImage = image else { return }
        ocrService.recognizeText(from: selectedImage) { transaction in
            if let transaction = transaction {
                self.amount = String(format: "%.2f", transaction.amount)
                self.date = transaction.date
                self.description = transaction.description
                self.selectedType = .expense
                if viewModel.categories(for: .expense).contains(transaction.category) {
                    self.category = transaction.category
                } else {
                    self.category = "未分类"
                }
                if viewModel.paymentMethods(for: .expense).contains(transaction.paymentMethod) {
                    self.paymentMethod = transaction.paymentMethod
                } else {
                    self.paymentMethod = viewModel.paymentMethods(for: .expense).first ?? "未知"
                }
                self.note = transaction.note
                self.showOcrSuccessAlert = true
            } else {
                self.showOcrFailureAlert = true
            }
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        if url.scheme == "smartbookkeeping" {
            isOpenedViaShortcuts = true
            if let imageData = try? Data(contentsOf: url) {
                if let image = UIImage(data: imageData) {
                    self.inputImage = image
                }
            }
        }
    }
    
    private func handleShortcutImageReceived(_ notification: Notification) {
        if let imageData = notification.object as? Data, let image = UIImage(data: imageData) {
            self.inputImage = image
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount) else {
            print("无效的金额输入")
            return
        }
        
        let transaction = Transaction(
            amount: abs(amountValue),
            date: date,
            category: category.isEmpty ? "未分类" : category,
            description: description,
            type: selectedType,
            paymentMethod: paymentMethod.isEmpty ? "未指定" : paymentMethod,
            note: note
        )
        
        viewModel.addTransaction(transaction)
        resetForm()
    }
    
    private func resetForm() {
        amount = ""
        date = Date()
        description = ""
        selectedType = .expense
        category = viewModel.categories(for: selectedType).first ?? "请选择分类"
        paymentMethod = viewModel.paymentMethods(for: selectedType).first ?? "请选择"
        note = ""
        inputImage = nil
    }
    
    private func loadTestImage(name: String) {
        if let testImage = UIImage(named: name) {
            self.inputImage = testImage
        } else {
            print("测试图片 \(name) 加载失败")
        }
    }
    
    private func applyProcessedData(_ data: TransactionData) {
        amount = String(format: "%.2f", data.amount)
        category = data.category
        date = data.date
        note = data.note
        selectedType = data.type
    }
}

#Preview {
    // 1. Get the preview context from your PersistenceController
    let previewContext = PersistenceController.preview.container.viewContext

    // 2. Create the TransactionViewModel with the context
    let transactionViewModel = TransactionViewModel(context: previewContext)

    // 3. Pass the initialized viewModel to your TransactionFormView
    TransactionFormView(viewModel: transactionViewModel)
}

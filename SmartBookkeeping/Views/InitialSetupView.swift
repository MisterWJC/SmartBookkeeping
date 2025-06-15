//
//  InitialSetupView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI
import AVFoundation

struct InitialSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: AIOnboardingStep = .welcome
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingSpeechRecognition = false
    @State private var capturedImage: UIImage?
    @State private var isProcessingAI = false
    @State private var aiResult: AIProcessingResult?
    @State private var showingResultConfirmation = false
    @State private var remainingFreeUses = ConfigurationManager.shared.freeUsesRemaining
    @State private var showingPaywall = false
    @State private var showingCategoryPicker = false
    @State private var showingAccountPicker = false
    @State private var showingAmountEditor = false
    @State private var showingDatePicker = false
    @State private var showingDescriptionEditor = false
    @State private var showingNotesEditor = false
    @State private var showingNotesSection = false
    @State private var validationErrors: [String] = []
    @State private var showingValidationAlert = false
    @State private var editableAmount = ""
    @State private var editableDescription = ""
    @State private var editableNotes = ""
    @State private var selectedDate = Date()
    @State private var selectedTransactionType: Transaction.TransactionType = .expense
    @State private var showingTransactionTypePicker = false
    
    // AI服务相关
    @StateObject private var aiService = AIService()
    @StateObject private var ocrService = OCRService()
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var transactionViewModel = TransactionViewModel(context: PersistenceController.shared.container.viewContext)
    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var formViewModel: TransactionFormViewModel
    
    // 语音录制相关
    @State private var isRecording = false
    @State private var pendingImage: UIImage? = nil
    
    init() {
        self._formViewModel = StateObject(wrappedValue: TransactionFormViewModel(context: PersistenceController.shared.container.viewContext))
    }
    
    private let categoryManager = CategoryDataManager.shared
    private let configManager = ConfigurationManager.shared
    
    enum AIOnboardingStep {
        case welcome
        case aiSelection
        case voiceGuide
        case processing
        case confirmation
        case completed
    }
    
    struct AIProcessingResult {
        var amount: Double
        var category: String
        var account: String
        var merchant: String
        var date: Date
        var description: String
        var notes: String?
        var transactionType: Transaction.TransactionType
        
        // AI置信度信息
        var confidenceScores: ConfidenceScores
        
        // ConfidenceScores 结构体已移动到 Models/ConfidenceScores.swift
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    switch currentStep {
                    case .welcome:
                        welcomeStepView
                    case .aiSelection:
                        aiSelectionStepView
                    case .voiceGuide:
                        voiceGuideStepView
                    case .processing:
                        processingStepView
                    case .confirmation:
                        confirmationStepView
                    case .completed:
                        completedStepView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            setupDefaultConfiguration()
        }
        .sheet(item: $formViewModel.activeSheet) { sheet in
            switch sheet {
            case .imagePicker: ImagePicker(image: $pendingImage)
            case .camera: CameraView(image: $pendingImage)
            case .csvImport: CSVImportView(viewModel: transactionViewModel)
            case .manualInput: ManualInputView(inputText: $formViewModel.quickInputText, onProcess: {
                    formViewModel.processQuickInput()
                }, viewModel: formViewModel)
            }
        }
        .alert(item: $formViewModel.alertItem) { alertItem in
            switch alertItem.type {
            case .confirmation:
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    primaryButton: .default(Text("确认")) {
                        alertItem.primaryAction?()
                    },
                    secondaryButton: .cancel(Text("取消")) {
                        alertItem.secondaryAction?()
                    }
                )
            case .processing:
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("确定"))
                )
            case .info, .error:
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
        .onChange(of: pendingImage) { image in
            if let image = image {
                processImageWithAI(image)
            }
        }
        .onChange(of: currentStep) {
            if currentStep == .aiSelection {
                setupDefaultConfiguration()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(onUpgrade: {
                // 处理升级逻辑
                showingPaywall = false
            })
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(
                selectedCategory: Binding(
                    get: { aiResult?.category ?? "" },
                    set: { newValue in
                        if var result = aiResult {
                            result.category = newValue
                            aiResult = result
                        }
                    }
                ),
                transactionType: selectedTransactionType
            )
        }
        .sheet(isPresented: $showingAccountPicker) {
            AccountPickerView(selectedAccount: Binding(
                get: { aiResult?.account ?? "" },
                set: { newValue in
                    if var result = aiResult {
                        result.account = newValue
                        aiResult = result
                    }
                }
            ))
        }
        .sheet(isPresented: $showingAmountEditor) {
            AmountEditorView(amount: $editableAmount) { newAmount in
                if var result = aiResult, let amount = Double(newAmount) {
                    result.amount = amount
                    aiResult = result
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("选择交易时间")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            showingDatePicker = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        
                        Button("保存") {
                            if var result = aiResult {
                                result.date = selectedDate
                                aiResult = result
                            }
                            showingDatePicker = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .navigationBarHidden(true)
            }
        }
        .sheet(isPresented: $showingDescriptionEditor) {
            TextEditorView(
                title: "编辑商品说明",
                text: $editableDescription
            ) { newDescription in
                if var result = aiResult {
                    result.description = newDescription
                    aiResult = result
                }
            }
        }
        .sheet(isPresented: $showingNotesEditor) {
            TextEditorView(
                title: "编辑备注",
                text: $editableNotes
            ) { newNotes in
                editableNotes = newNotes
            }
        }
        .sheet(isPresented: $showingTransactionTypePicker) {
            TransactionTypePickerView(selectedType: $selectedTransactionType) { newType in
                selectedTransactionType = newType
                if var result = aiResult {
                    result.transactionType = newType
                    aiResult = result
                }
            }
        }
    }
    
    // MARK: - 阶段一：极简欢迎页
    private var welcomeStepView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 动态图标动画
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                Text("你好，我是你的AI记账管家")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("把账单给我，剩下的交给我")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // 立即体验按钮
            Button(action: {
                withAnimation(.spring()) {
                    currentStep = .aiSelection
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("立即体验AI记账")
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 阶段二：AI功能选择台
    private var aiSelectionStepView: some View {
        VStack(spacing: 30) {
            // 顶部标题
            VStack(spacing: 12) {
                Text("选择AI记账方式")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.orange)
                    Text("您有 \(remainingFreeUses) 次免费AI记账体验")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // AI功能选择按钮
            VStack(spacing: 20) {
                AIFeatureButton(
                    icon: "camera.fill",
                    title: "拍照记账",
                    subtitle: "扫描小票，AI智能识别",
                    color: .blue
                ) {
                    if remainingFreeUses > 0 {
                        formViewModel.presentSheet(.camera)
                    } else {
                        showingPaywall = true
                    }
                }
                
                AIFeatureButton(
                    icon: "mic.fill",
                    title: "语音记账",
                    subtitle: "说句话就记账，解放双手",
                    color: .green
                ) {
                    if remainingFreeUses > 0 {
                        withAnimation {
                            currentStep = .voiceGuide
                        }
                    } else {
                        showingPaywall = true
                    }
                }
                
                AIFeatureButton(
                    icon: "photo.fill",
                    title: "相册识别",
                    subtitle: "选取支付截图，智能解析",
                    color: .purple
                ) {
                    if remainingFreeUses > 0 {
                        formViewModel.presentSheet(.imagePicker)
                    } else {
                        showingPaywall = true
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 跳过按钮
            Button("稍后体验") {
                completeOnboardingWithEmptyState()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - 阶段三：AI处理动画
    private var processingStepView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 魔法动画效果
            ZStack {
                // 外圈动画
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(1.5)
                    .opacity(0.5)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: UUID())
                
                // 中圈动画
                Circle()
                    .stroke(Color.purple.opacity(0.5), lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: UUID())
                
                // 内圈
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                // 中心图标
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isProcessingAI ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isProcessingAI)
            }
            
            VStack(spacing: 16) {
                Text("AI正在识别账单信息...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("正在为您智能分类和解析")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .onAppear {
            isProcessingAI = true
        }
    }
    
    // MARK: - 阶段四：确认与微调
    private var confirmationStepView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部标题
                VStack(spacing: 8) {
                    Text("AI识别结果")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("橙色标记的项目建议您确认一下")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // AI结果确认卡片
                if let result = aiResult {
                    VStack(spacing: 20) {
                        // 第一组：核心金额（突出显示）
                        VStack(spacing: 16) {
                            Text("¥ \(String(format: "%.2f", result.amount))")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            ClickableTagRow(
                                icon: "yensign.circle.fill",
                                title: "金额",
                                value: "¥\(String(format: "%.2f", result.amount))",
                                color: .green,
                                confidence: result.confidenceScores.amount
                            ) {
                                editableAmount = String(format: "%.2f", result.amount)
                                showingAmountEditor = true
                            }
                        }
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // 第二组：交易核心信息
                        VStack(spacing: 8) {
                            HStack {
                                Text("交易信息")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                // 商品说明 - 可折叠显示
                                if !result.description.isEmpty && result.description != "AI识别记录" {
                                    ClickableTagRow(
                                        icon: "text.alignleft",
                                        title: "商品说明",
                                        value: result.description,
                                        color: .orange,
                                        confidence: result.confidenceScores.description
                                    ) {
                                        editableDescription = result.description
                                        showingDescriptionEditor = true
                                    }
                                    
                                    Divider().padding(.leading, 50)
                                }
                                
                                ClickableTagRow(
                                    icon: "tag.fill",
                                    title: "交易分类",
                                    value: result.category,
                                    color: .blue,
                                    confidence: result.confidenceScores.category
                                ) {
                                    showingCategoryPicker = true
                                }
                                
                                Divider().padding(.leading, 50)
                                
                                ClickableTagRow(
                                    icon: "arrow.up.arrow.down.circle.fill",
                                    title: "收入/支出",
                                    value: selectedTransactionType.rawValue,
                                    color: selectedTransactionType == .income ? .green : .red,
                                    confidence: 0.8 // 收支类型通常置信度较高
                                ) {
                                    showingTransactionTypePicker = true
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // 第三组：账户与时间信息
                        VStack(spacing: 8) {
                            HStack {
                                Text("账户与时间")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ClickableTagRow(
                                    icon: "creditcard.fill",
                                    title: "账户",
                                    value: result.account,
                                    color: .green,
                                    confidence: result.confidenceScores.account
                                ) {
                                    showingAccountPicker = true
                                }
                                
                                Divider().padding(.leading, 50)
                                
                                ClickableTagRow(
                                    icon: "clock.fill",
                                    title: "交易时间",
                                    value: formatTransactionTime(result.date),
                                    color: .purple,
                                    confidence: result.confidenceScores.date
                                ) {
                                    selectedDate = result.date
                                    showingDatePicker = true
                                }
                                
                                // 备注 - 放在最底部，可选展开
                                if showingNotesSection {
                                    Divider().padding(.leading, 50)
                                    
                                    ClickableTagRow(
                                        icon: "note.text",
                                        title: "备注",
                                        value: editableNotes.isEmpty ? "点击添加备注" : editableNotes,
                                        color: .gray,
                                        confidence: result.confidenceScores.notes
                                    ) {
                                        showingNotesEditor = true
                                    }
                                } else {
                                    Divider().padding(.leading, 50)
                                    
                                    Button("添加备注") {
                                        showingNotesSection = true
                                        showingNotesEditor = true
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                }
            
            Spacer()
            
            // 底部按钮
            VStack(spacing: 16) {
                // 确认入账按钮（主要操作）
                Button(action: {
                    if validateTransaction() {
                        confirmAndSaveTransaction()
                    } else {
                        showingValidationAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("确认入账")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isValidTransaction() ? 
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray, Color.gray]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: isValidTransaction() ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .alert("数据验证失败", isPresented: $showingValidationAlert) {
                    Button("确定", role: .cancel) { }
                } message: {
                    Text(validationErrors.joined(separator: "\n"))
                }
                
                // 重新识别按钮（次要操作 - 幽灵按钮）
                Button(action: {
                    withAnimation {
                        currentStep = .aiSelection
                        aiResult = nil
                        showingNotesSection = false
                        editableAmount = ""
                        editableDescription = ""
                        editableNotes = ""
                        selectedDate = Date()
                        selectedTransactionType = .expense
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                        Text("重新识别")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
    // MARK: - 阶段五：完成页面
    private var completedStepView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 成功动画
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: UUID())
            }
            
            VStack(spacing: 16) {
                Text("记账成功！")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("您的第一笔AI记账已完成")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if remainingFreeUses > 0 {
                    Text("还剩 \(remainingFreeUses) 次免费体验")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button("查看我的第一笔记账") {
                    completeOnboarding()
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                
                Button("继续体验AI记账") {
                    withAnimation {
                        currentStep = .aiSelection
                        aiResult = nil
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
    }
    
    // MARK: - 辅助方法
    
    private func setupDefaultConfiguration() {
        // 设置默认的AI配置，使用内置的免费额度
        configManager.setDefaultAIConfiguration()
        accountViewModel.fetchAccounts()
        
        // 同步免费使用次数
        remainingFreeUses = configManager.freeUsesRemaining
        
        // 初始化默认分类和账户
        if !categoryManager.hasCompletedInitialSetup() {
            categoryManager.initializeDefaultCategories()
            categoryManager.initializeDefaultAccounts()
        }
    }
    
    private func processImageWithAI(_ image: UIImage) {
        withAnimation {
            currentStep = .processing
        }
        
        // 使用真实的图片处理功能
        formViewModel.showImageConfirmation(
            for: image,
            onConfirm: {
                formViewModel.formData.image = image
                formViewModel.handleImageSelected(image)
                
                // 等待AI处理完成后显示结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    let result = AIProcessingResult(
                        amount: Double(formViewModel.formData.amount) ?? 0.0,
                        category: formViewModel.formData.category.isEmpty ? "其他" : formViewModel.formData.category,
                        account: formViewModel.formData.paymentMethod.isEmpty ? "现金" : formViewModel.formData.paymentMethod,
                        merchant: "",
                        date: formViewModel.formData.date,
                        description: formViewModel.formData.description.isEmpty ? "AI识别记录" : formViewModel.formData.description,
                        notes: "AI处理结果",
                        transactionType: formViewModel.formData.type,
                        confidenceScores: ConfidenceScores()
                    )
                    
                    aiResult = result
                    configManager.consumeFreeUse()
                    remainingFreeUses = configManager.freeUsesRemaining
                    
                    withAnimation {
                        currentStep = .confirmation
                    }
                }
            },
            onCancel: {
                pendingImage = nil
                withAnimation {
                    currentStep = .aiSelection
                }
            }
        )
    }
    
    private func startVoiceRecording() {
        if !isRecording {
            formViewModel.startVoiceRecording()
            isRecording = true
            withAnimation {
                currentStep = .processing
            }
        }
    }
    
    private func stopVoiceRecording() {
        if isRecording {
            formViewModel.stopVoiceRecordingAndProcess()
            isRecording = false
            // 处理语音识别结果
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if !formViewModel.formData.description.isEmpty {
                    let mockResult = AIProcessingResult(
                        amount: 0.0, // 需要用户手动输入
                        category: formViewModel.formData.category.isEmpty ? "其他" : formViewModel.formData.category,
                        account: formViewModel.formData.paymentMethod.isEmpty ? "现金" : formViewModel.formData.paymentMethod,
                        merchant: "",
                        date: Date(),
                        description: formViewModel.formData.description,
                        notes: "AI识别记录",
                        transactionType: .expense,
                        confidenceScores: ConfidenceScores()
                    )
                    
                    aiResult = mockResult
                    configManager.consumeFreeUse()
                    remainingFreeUses = configManager.freeUsesRemaining
                    
                    withAnimation {
                        currentStep = .confirmation
                    }
                } else {
                    // 语音识别失败，返回选择界面
                    withAnimation {
                        currentStep = .aiSelection
                    }
                }
            }
        }
    }
    
    private func parseTransactionTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        return formatter.date(from: timeString)
    }
    
    private func confirmAndSaveTransaction() {
        guard let result = aiResult else { return }
        
        // 保存交易记录
        let transaction = Transaction(
            id: UUID(),
            amount: result.amount,
            date: result.date,
            category: result.category,
            description: result.description,
            type: .expense,
            paymentMethod: result.account,
            note: "AI识别记录"
        )
        transactionViewModel.addTransaction(transaction)
        
        // 显示成功动画
        withAnimation(.spring()) {
            currentStep = .completed
        }
    }
    
    private func formatTransactionTime(_ date: Date) -> String {
         let formatter = DateFormatter()
         formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
         return formatter.string(from: date)
     }
    
    private func completeOnboarding() {
        categoryManager.markInitialSetupCompleted()
        dismiss()
    }
    
    private func completeOnboardingAndShowDetail() {
        categoryManager.markInitialSetupCompleted()
        dismiss()
        // 发送通知切换到明细页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToDetailTab"), object: nil)
        }
    }
    
    private func completeOnboardingWithEmptyState() {
        categoryManager.markInitialSetupCompleted()
        dismiss()
        // 发送通知显示空状态引导
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: NSNotification.Name("ShowEmptyStateGuide"), object: nil)
        }
    }
    
    private func isValidTransaction() -> Bool {
        guard let result = aiResult else { return false }
        return result.amount > 0 && !result.category.isEmpty && !result.account.isEmpty
    }
    
    private func validateTransaction() -> Bool {
        guard let result = aiResult else {
            validationErrors = ["无效的交易数据"]
            return false
        }
        
        let errors = ValidationUtils.validateTransaction(
            amount: result.amount,
            category: result.category,
            account: result.account,
            description: result.description,
            date: result.date
        )
        
        validationErrors = errors
        return validationErrors.isEmpty
    }
    
    private func saveTransaction() {
        confirmAndSaveTransaction()
    }
    
    // MARK: - 语音引导视图
    private var voiceGuideStepView: some View {
        VoiceRecordingGuideView(
            onRecordingComplete: { aiResponse in
                // 处理AI识别结果
                let processedResult = AIProcessingResult(
                    amount: aiResponse.amount ?? 0.0,
                    category: aiResponse.category ?? "其他",
                    account: aiResponse.payment_method ?? "现金",
                    merchant: "",
                    date: Date(),
                    description: aiResponse.item_description ?? "",
                    notes: aiResponse.notes,
                    transactionType: .expense,
                    confidenceScores: ConfidenceScores()
                )
                
                // 更新表单数据
                formViewModel.formData.description = aiResponse.item_description ?? ""
                
                aiResult = processedResult
                    selectedTransactionType = .expense
                    configManager.consumeFreeUse()
                    remainingFreeUses = configManager.freeUsesRemaining
                    
                    withAnimation {
                        currentStep = .confirmation
                    }
            },
            onCancel: {
                withAnimation {
                    currentStep = .aiSelection
                }
            }
        )
    }
}

// MARK: - 辅助视图组件

struct AIFeatureButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ClickableTagRow已在单独文件中定义，删除重复定义
//             }
//             .padding(.horizontal, 20)
//             .padding(.vertical, 16)
//         }
//         .buttonStyle(PlainButtonStyle())
//     }
// }

struct PaywallView: View {
    let onUpgrade: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("升级到Pro版")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("看起来你很喜欢AI记账的便捷\n升级到Pro版，继续享受极致效率")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                PricingOption(title: "月度订阅", price: "¥10/月", features: ["无限AI记账", "高级统计分析", "数据导出"])
                PricingOption(title: "年度订阅", price: "¥60/年", originalPrice: "¥120", features: ["无限AI记账", "高级统计分析", "数据导出", "优先客服支持"])
            }
            
            Button("立即升级") {
                onUpgrade()
            }
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange)
            .cornerRadius(16)
            
            Button("稍后再说") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
    }
}

struct PricingOption: View {
    let title: String
    let price: String
    let originalPrice: String?
    let features: [String]
    
    init(title: String, price: String, originalPrice: String? = nil, features: [String]) {
        self.title = title
        self.price = price
        self.originalPrice = originalPrice
        self.features = features
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let originalPrice = originalPrice {
                        Text(originalPrice)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                    Text(price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 扩展

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

#Preview {
    InitialSetupView()
}

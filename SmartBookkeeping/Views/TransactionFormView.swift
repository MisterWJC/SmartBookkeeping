//
//  TransactionFormView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI
import CoreData

enum FormField: Hashable {
    case amount, description, note
}

struct TransactionFormView: View {
    // ViewModel is now the single source of truth for the view's state and logic.
    @StateObject private var viewModel: TransactionFormViewModel
    @StateObject private var accountViewModel = AccountViewModel()
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FormField?
    @EnvironmentObject var shortcutManager: ShortcutManager
    
    // Add TransactionViewModel to refresh data after saving
    let transactionViewModel: TransactionViewModel?
    
    // 呼吸灯效果状态
    @State private var shouldShowBreathingEffect = false
    @State private var breathingScale: CGFloat = 1.0
    
    // Enum for input modes, kept in the View as it's a pure UI concern.
    enum InputMode {
        case text, voice
    }
    
    // The initializer now requires the context to create its ViewModel.
    init(context: NSManagedObjectContext, transactionViewModel: TransactionViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: TransactionFormViewModel(context: context))
        self.transactionViewModel = transactionViewModel
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                newInputModuleView
                formSections
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("智能记账助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("体验AI引导") {
                        // 发送通知给ContentView显示引导界面
                        NotificationCenter.default.post(name: NSNotification.Name("ShowAIGuide"), object: nil)
                    }
                    .font(.caption)
                    .foregroundColor(shouldShowBreathingEffect ? .white : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(aiGuideButtonBackground)
                    .scaleEffect(shouldShowBreathingEffect ? breathingScale : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: breathingScale)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .onAppear {
                // Set up callback to refresh transaction data when saved
                viewModel.onTransactionSaved = {
                    transactionViewModel?.fetchTransactions()
                }
                // 初始化时获取账户数据
                accountViewModel.fetchAccounts()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowEmptyStateGuide"))) { _ in
                // 显示呼吸灯效果
                shouldShowBreathingEffect = true
                breathingScale = 1.15
                // 8秒后停止呼吸灯效果
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    shouldShowBreathingEffect = false
                    breathingScale = 1.0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccountDeleted"))) { _ in
                // 当收到账户删除通知时，刷新账户列表
                accountViewModel.fetchAccounts()
                // 如果当前选中的账户被删除，重置选择
                if !accountViewModel.accounts.contains(where: { $0.name == viewModel.formData.account }) {
                    viewModel.formData.account = ""
                }
            }
            .onChange(of: shortcutManager.shouldShowEditForm) { shouldShow in
                if shouldShow && !shortcutManager.editFormData.isEmpty {
                    // 填充表单数据
                    viewModel.populateFromURLData(shortcutManager.editFormData)
                    // 重置 ShortcutManager 状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shortcutManager.shouldShowEditForm = false
                        shortcutManager.editFormData = [:]
                    }
                }
            }
            // 移除onChange监听器，因为图片处理现在通过确认对话框处理
            // Add other handlers like .onOpenURL that call viewModel methods.
        }
        .modifier(SheetAndAlertModifier(viewModel: viewModel))
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - View Modifier for Sheets and Alerts
    private struct SheetAndAlertModifier: ViewModifier {
        @ObservedObject var viewModel: TransactionFormViewModel
        @State private var pendingImage: UIImage? = nil

        func body(content: Content) -> some View {
            content
                .onChange(of: pendingImage) { newImage in
                    if let image = newImage {
                        viewModel.showImageConfirmation(
                            for: image,
                            onConfirm: {
                                viewModel.formData.image = image
                                viewModel.handleImageSelected(image)
                                pendingImage = nil
                            },
                            onCancel: {
                                pendingImage = nil
                            }
                        )
                    }
                }
                .sheet(item: $viewModel.activeSheet) { sheet in
                    switch sheet {
                    case .imagePicker: ImagePicker(image: $pendingImage)
                    case .camera: CameraView(image: $pendingImage)
                    case .csvImport: CSVImportView(viewModel: TransactionViewModel(context: self.viewModel.context))
                    case .manualInput: ManualInputView(inputText: $viewModel.quickInputText, onProcess: {
                            viewModel.processQuickInput()
                        }, viewModel: viewModel)
                    }
                }
                .alert(item: $viewModel.alertItem) { alertItem in
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
        }
    }
    
    // MARK: - Computed Properties
    
    private var aiGuideButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(shouldShowBreathingEffect ? 
                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing) : 
                LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
            )
            .scaleEffect(shouldShowBreathingEffect ? breathingScale : 1.0)
            .shadow(color: shouldShowBreathingEffect ? .purple.opacity(0.6) : .clear, radius: shouldShowBreathingEffect ? 8 : 0)
    }
    
    // MARK: - Subviews
    
    private var formSections: some View {
        Form {
            Section(header: Text("金额")) {
                TextField("请输入金额", text: $viewModel.formData.amount)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
            }
            
            Section(header: Text("交易日期")) {
                DatePicker("", selection: $viewModel.formData.date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
            }
            
            
            Section(header: Text("收/支类型")) {
                Picker("收/支类型", selection: $viewModel.formData.type) {
                    ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: viewModel.formData.type) { newType in
                    viewModel.updateCategoryForType(newType)
                }
            }

            Section(header: Text("交易分类")) {
                Picker("请选择分类", selection: $viewModel.formData.category) {
                    ForEach(viewModel.categoriesForSelectedType, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            Section("商品明细") {
                TextField("请输入商品明细", text: $viewModel.formData.description)
                    .focused($focusedField, equals: .description)
            }

            Section(header: Text("付款/收款方式")) {
                Picker("请选择收/付款方式", selection: $viewModel.formData.paymentMethod) {
                    // 显示现有账户
                    ForEach(accountViewModel.accounts, id: \.id) { account in
                        Text(account.name ?? "未知账户").tag(account.name ?? "")
                    }
                    
                    // 显示传统支付方式（向后兼容）
                    ForEach(viewModel.paymentMethodsForSelectedType.filter { method in
                        !accountViewModel.accounts.contains { $0.name == method }
                    }, id: \.self) { method in
                        Text(method).tag(method)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                

            }

            Section("备注") {
                TextEditor(text: $viewModel.formData.note)
                    .frame(minHeight: 100)
                    .focused($focusedField, equals: .note)
            }
            
            Section {
                Button(action: viewModel.saveTransaction) {
                    Text("保存")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .listRowInsets(EdgeInsets())
                
                Button(action: viewModel.resetForm) {
                    Text("重置")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                .listRowInsets(EdgeInsets())
            }
        }
    }
    
    // MARK: - New Input Module
    
    private var newInputModuleView: some View {
        VStack(spacing: 12) {
            quickInputBarView
            if viewModel.showExtraButtons {
                actionButtonsRowView
            }
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 8)
        .background(Color(UIColor.systemGray6))
    }
    
    @ViewBuilder
    private var quickInputBarView: some View {
        switch viewModel.inputMode {
        case .text: textInputModeBarView
        case .voice: voiceInputModeBarView
        }
    }
    
    private var textInputModeBarView: some View {
        HStack {
            Button(action: viewModel.toggleExtraButtons) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            
            HStack {
                Text("一句话记录～")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(8)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .onTapGesture { viewModel.presentSheet(.manualInput) }

            Button(action: { viewModel.changeInputMode(to: .voice) }) {
                Image(systemName: "mic.fill").foregroundColor(.blue)
            }
        }
        .padding(6)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(16)
    }

    private var voiceInputModeBarView: some View {
        HStack {
            Button(action: viewModel.toggleExtraButtons) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            
            HStack {
                Text(viewModel.isRecording ? "正在录音..." : "长按说话，快速记录")
                    .foregroundColor(viewModel.isRecording ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(8)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !viewModel.isRecording {
                                    viewModel.startVoiceRecording()
                                }
                            }
                            .onEnded { _ in
                                if viewModel.isRecording {
                                    viewModel.stopVoiceRecordingAndProcess()
                                }
                            }
                    )

            Button(action: { viewModel.changeInputMode(to: .text) }) {
                Image(systemName: "keyboard").foregroundColor(.blue)
            }
        }
        .padding(6)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(16)
    }

    private var actionButtonsRowView: some View {
        HStack(spacing: 16) {
            Spacer()
            actionButton(title: "相册", icon: "photo.on.rectangle.angled", disabled: viewModel.isProcessingAI) {
                viewModel.presentSheet(.imagePicker)
            }
            Spacer()
            actionButton(title: "拍照", icon: "camera.fill", disabled: viewModel.isProcessingAI) {
                // You'd add camera availability check in ViewModel
                viewModel.presentSheet(.camera)
            }
            Spacer()
            actionButton(title: "账单导入", icon: "doc.badge.plus", disabled: false) {
                viewModel.presentSheet(.csvImport)
            }
            Spacer()
        }
    }

    private func actionButton(title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .background(disabled ? Color(UIColor.systemGray4) : Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2, y: 1)
                    .opacity(disabled ? 0.6 : 1.0)
                Text(title)
                    .font(.caption)
                    .opacity(disabled ? 0.6 : 1.0)
            }
        }
        .disabled(disabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// Dummy views for compilation. Replace with your actual implementations.
struct ManualInputView: View {
    @Binding var inputText: String
    @State private var isProcessing = false
    @Environment(\.presentationMode) private var presentationMode
    var onProcess: () -> Void
    
    // 添加对viewModel的引用
    let viewModel: TransactionFormViewModel
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("手动输入")
                        .font(.headline)
                    
                    Spacer()
                    
                    // 移除确认按钮，保持布局平衡
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.clear) // 透明占位
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                // 文本输入区域
                TextEditor(text: $inputText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                
                // 底部工具栏
                HStack {
                    // 左侧按钮组
                    HStack(spacing: 20) {
                        Button(action: {
                        viewModel.activeSheet = .imagePicker
                    }) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(viewModel.isProcessingAI ? .secondary : .primary)
                        }
                        .disabled(viewModel.isProcessingAI)
                        
                        Button(action: {
                        viewModel.activeSheet = .camera
                    }) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(viewModel.isProcessingAI ? .secondary : .primary)
                        }
                        .disabled(viewModel.isProcessingAI)
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    // 右侧上传按钮
                    Button(action: {
                        isProcessing = true
                        onProcess() // 调用 onProcess 回调，触发 processQuickInput 方法
                        presentationMode.wrappedValue.dismiss() // 自动退出到记账页面
                    }) {
                        Text(viewModel.isProcessingAI ? "处理中..." : "上传并识别")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .disabled(isProcessing || inputText.isEmpty || viewModel.isProcessingAI)
                    .padding(.trailing)
                }
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
            }
            

        }
    }

}
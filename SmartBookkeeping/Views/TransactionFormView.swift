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
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FormField?
    
    // Add TransactionViewModel to refresh data after saving
    let transactionViewModel: TransactionViewModel?
    
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
            }
            // 移除重复的 sheet 定义，使用 SheetAndAlertModifier 中的统一管理
            .alert(item: $viewModel.alertItem) { item in
                Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("确定")))
            }
            .onChange(of: viewModel.formData.image) { _, newImage in
                viewModel.handleImageSelected(newImage)
            }
            // Add other handlers like .onOpenURL that call viewModel methods.
        }
        .modifier(SheetAndAlertModifier(viewModel: viewModel))
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - View Modifier for Sheets and Alerts
    private struct SheetAndAlertModifier: ViewModifier {
        @ObservedObject var viewModel: TransactionFormViewModel
        @State private var showImageConfirmation: Bool = false
        @State private var pendingImage: UIImage? = nil

        func body(content: Content) -> some View {
            content
                .sheet(item: $viewModel.activeSheet, onDismiss: {
                    // 确保在相册或相机关闭后，如果有选择图片，显示确认对话框
                    if pendingImage != nil {
                        // 在主线程更新UI，并添加延迟以确保sheet已完全关闭
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImageConfirmation = true
                        }
                    }
                }) { sheet in
                    switch sheet {
                    case .imagePicker: ImagePicker(image: $pendingImage)
                    case .camera: CameraView(image: $pendingImage)
                    case .csvImport: CSVImportView(viewModel: TransactionViewModel(context: self.viewModel.context))
                    case .manualInput: ManualInputView(inputText: $viewModel.quickInputText) {
                            viewModel.processQuickInput()
                        }
                    }
                }
                .alert(item: $viewModel.alertItem) { item in
                    Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("确定")))
                }
                .alert("确认使用此图片？", isPresented: $showImageConfirmation) {
                    Button("确认") {
                        if let image = pendingImage {
                            viewModel.formData.image = image
                            pendingImage = nil
                        }
                    }
                    Button("取消", role: .cancel) {
                        pendingImage = nil
                    }
                }
        }
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
            }
            
            Section(header: Text("收/支类型")) {
                Picker("请选择", selection: $viewModel.formData.type) {
                    ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("交易分类")) {
                Picker("请选择分类", selection: $viewModel.formData.category) {
                    ForEach(viewModel.categoriesForSelectedType, id: \.self) { Text($0) }
                }
                .pickerStyle(MenuPickerStyle())
            }

            Section(header: Text("商品明细")) {
                TextField("例：超市购物/餐饮消费", text: $viewModel.formData.description)
                    .focused($focusedField, equals: .description)
            }

            Section(header: Text("付款/收款方式")) {
                Picker("请选择", selection: $viewModel.formData.paymentMethod) {
                    ForEach(viewModel.paymentMethodsForSelectedType, id: \.self) { Text($0) }
                }
                .pickerStyle(MenuPickerStyle())
            }

            Section(header: Text("备注")) {
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
            
            Text("一句话记录～")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            
            Text(viewModel.isRecording ? "正在录音..." : "长按说话，快速记录")
                .foregroundColor(viewModel.isRecording ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            actionButton(title: "相册", icon: "photo.on.rectangle.angled") {
                viewModel.presentSheet(.imagePicker)
            }
            Spacer()
            actionButton(title: "拍照", icon: "camera.fill") {
                // You'd add camera availability check in ViewModel
                viewModel.presentSheet(.camera)
            }
            Spacer()
            actionButton(title: "账单导入", icon: "doc.badge.plus") {
                viewModel.presentSheet(.csvImport)
            }
            Spacer()
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title)
                    .frame(width: 60, height: 60)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2, y: 1)
                Text(title).font(.caption)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Dummy views for compilation. Replace with your actual implementations.
struct ManualInputView: View {
    @Binding var inputText: String
    @State private var showImageConfirmation = false
    @State private var pendingImage: UIImage?
    @State private var isProcessing = false
    @Environment(\.presentationMode) private var presentationMode
    var onProcess: () -> Void
    
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
                            // 确保当前没有其他sheet正在显示
                            if !showImageConfirmation {
                                // 使用 ImagePicker 直接获取图片
                                showImagePicker()
                            }
                        }) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            // 确保当前没有其他sheet正在显示
                            if !showImageConfirmation {
                                // 使用 CameraView 直接获取图片
                                showCamera()
                            }
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    // 右侧上传按钮
                    Button(action: {
                        isProcessing = true
                        onProcess() // 调用 onProcess 回调，触发 processQuickInput 方法
                        presentationMode.wrappedValue.dismiss() // 自动退出到记账页面
                    }) {
                        Text("上传并识别")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .disabled(isProcessing || inputText.isEmpty)
                    .padding(.trailing)
                }
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
            }
            
            // 使用全屏覆盖的方式显示确认对话框
            if showImageConfirmation, let imageToConfirm = pendingImage {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // 点击背景取消确认
                        showImageConfirmation = false
                        pendingImage = nil
                    }
                
                VStack(spacing: 20) {
                    Text("确认使用此截图?")
                        .font(.headline)
                    
                    Image(uiImage: imageToConfirm)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                    
                    Text("确认使用选择的截图进行账单识别?")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 30) {
                        Button(action: {
                            showImageConfirmation = false
                            pendingImage = nil
                        }) {
                            Text("取消")
                                .frame(width: 100)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            if let confirmedImage = pendingImage {
                                // 在主线程更新UI
                                DispatchQueue.main.async {
                                    handleSelectedImage(confirmedImage)
                                }
                            }
                            showImageConfirmation = false
                            pendingImage = nil
                        }) {
                            Text("确认")
                                .frame(width: 100)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(30)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(30)
            }
        }
        // 移除重复的 sheet 定义，统一使用 SheetAndAlertModifier 管理
    }
    
    // 添加显示图片选择器的方法
    private func showImagePicker() {
        // 使用 ImagePicker 获取图片
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = ImagePickerDelegate(onImagePicked: { selectedImage in
            self.pendingImage = selectedImage
            self.showImageConfirmation = true
        })
        UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
    }
    
    // 添加显示相机的方法
    private func showCamera() {
        // 检查相机是否可用
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return
        }
        
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = ImagePickerDelegate(onImagePicked: { selectedImage in
            self.pendingImage = selectedImage
            self.showImageConfirmation = true
        })
        UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
    }
    
    // 图片选择器代理
    private class ImagePickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        
        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
            super.init()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // 延迟处理图片，避免视图控制器冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onImagePicked(image)
                }
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
    
    private func handleSelectedImage(_ selectedImage: UIImage) {
        isProcessing = true
        
        // 1. 使用 OCR 服务识别图片文本
        let ocrService = OCRService()
        ocrService.recognizeText(from: selectedImage) { ocrResult in
            // 2. 使用 AI 服务处理识别结果
            if let textResult = ocrResult {
                AIService.shared.processText(textResult.description, completion: { aiResponse in
                    // 确保在主线程更新UI
                    DispatchQueue.main.async {
                        // 使用 BillProcessingService 格式化 AI 响应
                        let formattedText = BillProcessingService.shared.formatAIResponseToText(aiResponse)
                        self.inputText = formattedText
                        self.isProcessing = false
                    }
                })
            } else {
                // 确保在主线程更新UI
                DispatchQueue.main.async {
                    self.inputText = "无法识别图片文本，请重试或手动输入。"
                    self.isProcessing = false
                }
            }
        }
    }
}
//
//  TransactionFormView.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

enum FormField: Hashable {
    case amount, description, note
}

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransactionViewModel
    @FocusState private var focusedField: FormField? // 新增 @FocusState
    
    // 表单数据
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var description: String = ""
    @State private var category: String = "请选择分类" // 修改初始值
    @State private var selectedType: Transaction.TransactionType = .expense
    @State private var paymentMethod: String = "请选择" // 修改初始值
    @State private var note: String = ""
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false // 新增状态，用于控制ActionSheet的显示
    @State private var inputImage: UIImage?
    @State private var isOpenedViaShortcuts: Bool = false
    private let ocrService = OCRService()
    
    // 新增状态变量用于按钮反馈
    @State private var saveButtonPressed = false
    @State private var resetButtonPressed = false
    
    // 注意：categories 和 paymentMethods 现在从 viewModel 获取，不再是静态私有变量
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear // 添加透明背景层
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                Form {
                    Section(header: Text("金额")) {
                        TextField("请输入金额", text: $amount)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount) // 绑定焦点
                    }
                    
                    Section(header: Text("交易日期")) {
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute]) // 修改此处
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                    }

                    Section(header: Text("收/支类型")) {
                        Picker("请选择", selection: $selectedType) {
                            ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section(header: Text("交易分类")) {
                        Picker("请选择分类", selection: $category) {
                            ForEach(viewModel.categories(for: selectedType), id: \.self) { // 使用 viewModel 的动态列表
                                Text($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedType) { oldValue, newValue in // 当收支类型改变时，如果当前分类不在新列表中，则重置分类
                            if !viewModel.categories(for: newValue).contains(category) {
                                category = viewModel.categories(for: newValue).first ?? ""
                            }
                        }
                    }
                    
                    Section(header: Text("商品明细")) {
                        TextField("例：超市购物/餐饮消费", text: $description)
                            .keyboardType(.default) // 确保弹出系统默认输入法
                            .focused($focusedField, equals: .description) // 绑定焦点
                    }
                    
                    Section(header: Text("付款/收款方式")) {
                        Picker("请选择", selection: $paymentMethod) {
                            ForEach(viewModel.paymentMethods(for: selectedType), id: \.self) { // 使用 viewModel 的动态列表
                                Text($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedType) { oldValue, newValue in // 当收支类型改变时，如果当前支付方式不在新列表中，则重置支付方式
                            if !viewModel.paymentMethods(for: newValue).contains(paymentMethod) {
                                paymentMethod = viewModel.paymentMethods(for: newValue).first ?? ""
                            }
                        }
                    }
                    
                    Section(header: Text("备注")) {
                        TextEditor(text: $note)
                            .frame(height: 100)
                            .focused($focusedField, equals: .note) // 绑定焦点
                    }
                    
                    Section {
                        Button(action: {
                            // 确保UI更新在主线程
                            DispatchQueue.main.async {
                                saveButtonPressed = true
                            }
                            // 模拟耗时操作后恢复状态，实际应在saveTransaction完成后
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                saveButtonPressed = false
                            }
                            saveTransaction()
                        }) {
                            Text("保存")
                                .frame(maxWidth: .infinity)
                                .padding() // 增加内边距使背景更明显
                                .background(saveButtonPressed ? Color.green.opacity(0.7) : Color.blue) // 直接在Text上应用背景
                                .foregroundColor(.white)
                                .cornerRadius(8) // 可选：添加圆角
                        }
                        .listRowInsets(EdgeInsets()) // 移除默认的list row边距，让背景填满
                        
                        Button(action: {
                            // 确保UI更新在主线程
                            DispatchQueue.main.async {
                                resetButtonPressed = true
                            }
                            // 模拟耗时操作后恢复状态，实际应在resetForm完成后
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                resetButtonPressed = false
                            }
                            resetForm()
                        }) { 
                            Text("重置")
                                .frame(maxWidth: .infinity)
                                .padding() // 增加内边距使背景更明显
                                .background(resetButtonPressed ? Color.orange.opacity(0.7) : Color.gray.opacity(0.2)) // 直接在Text上应用背景
                                .foregroundColor(.primary)
                                .cornerRadius(8) // 可选：添加圆角
                        }
                        .listRowInsets(EdgeInsets()) // 移除默认的list row边距，让背景填满
                    }
                    
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
                            .frame(height: 70) // Adjust height as needed
                        }
                    }
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
                        .cancel()
                    ])
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(image: $inputImage)
                }
                .onChange(of: inputImage) { oldValue, newValue in
                    guard let selectedImage = newValue else { return }
                    ocrService.recognizeText(from: selectedImage) { transaction in
                        if let transaction = transaction {
                            self.amount = String(format: "%.2f", transaction.amount)
                            self.date = transaction.date
                            self.description = transaction.description
                            self.selectedType = .expense // 强制设置为支出类型
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
                        }
                    }
                }
            }
        }
        .onOpenURL { url in
            if url.scheme == "smartbookkeeping" {
                isOpenedViaShortcuts = true
                // 这里可以处理从快捷指令传来的数据，例如图片
                // 假设快捷指令传递了一个图片的 Data
                if let imageData = try? Data(contentsOf: url) {
                    if let image = UIImage(data: imageData) {
                        self.inputImage = image
                    }
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let rawAmountValue = Double(amount) else { // 先确保能转换为Double
            // 金额无效，可以考虑给用户提示
            print("无效的金额输入")
            return
        }
        
        // 根据交易类型调整金额的符号，支出为负，收入为正
        // 或者，更常见的做法是，金额始终为正，通过交易类型（支出/收入）来区分
        // 这里我们采用金额始终为正，由type区分的策略
        let amountValue = abs(rawAmountValue) // 取绝对值

        // 检查金额是否大于0，因为金额不能为0或负数（在已取绝对值的情况下）
        guard amountValue > 0 else {
            print("金额必须大于0")
            return
        }
        
        let transaction = Transaction(
            amount: amountValue, // 保存绝对值金额
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
        selectedType = .expense // 先确定类型，再根据类型设置默认分类和支付方式
        category = viewModel.categories(for: selectedType).first ?? "请选择分类" 
        paymentMethod = viewModel.paymentMethods(for: selectedType).first ?? "请选择"
        note = ""
        inputImage = nil // 重置时也清空选择的图片
    }
    
    // 新增方法：加载项目内的测试图片
    private func loadTestImage(name: String) {
        if let testImage = UIImage(named: name) {
            self.inputImage = testImage
        } else {
            print("测试图片 \(name) 加载失败")
        }
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

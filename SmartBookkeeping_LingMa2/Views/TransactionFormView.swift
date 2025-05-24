//
//  TransactionFormView.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransactionViewModel
    
    // 表单数据
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var description: String = ""
    @State private var category: String = ""
    @State private var selectedType: Transaction.TransactionType = .expense
    @State private var paymentMethod: String = ""
    @State private var note: String = ""
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false // 新增状态，用于控制ActionSheet的显示
    @State private var inputImage: UIImage?
    private let ocrService = OCRService()
    
    // 注意：categories 和 paymentMethods 现在从 viewModel 获取，不再是静态私有变量
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("本月统计")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("本月支出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("¥\(viewModel.currentMonthExpense, specifier: "%.2f")")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("本月收入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("¥\(viewModel.currentMonthIncome, specifier: "%.2f")")
                                .font(.headline)
                        }
                    }
                    
                    // 饼图
                    ChartView(data: viewModel.getTransactionTypeDistribution())
                        .frame(height: 200)
                        .padding(.vertical)
                }
                
                Section(header: Text("金额")) {
                    TextField("请输入金额", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("交易日期")) {
                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                }
                
                Section(header: Text("商品类别")) {
                    TextField("例：超市购物/餐饮消费", text: $description)
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
                
                Section(header: Text("收/支类型")) {
                    Picker("请选择", selection: $selectedType) {
                        ForEach(Transaction.TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
                }
                
                Section {
                    Button(action: saveTransaction) {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    
                    Button(action: { dismiss() }) {
                        Text("重置")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.primary)
                    }
                    .listRowBackground(Color.gray.opacity(0.2))
                }
                
                Section {
                    Text("最近账单")
                        .font(.headline)
                    
                    if viewModel.transactions.isEmpty {
                        Text("暂无账单记录。")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("智能记账助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("上传数据") { // 修改按钮文字
                        showingActionSheet = true // 点击按钮时显示ActionSheet
                    }
                    .actionSheet(isPresented: $showingActionSheet) { // 添加ActionSheet
                        ActionSheet(title: Text("选择图像来源"), buttons: [
                            .default(Text("从相册选择")) { showingImagePicker = true },
                            .default(Text("加载测试图片1 (生活服务)")) { loadTestImage(name: "sample_bill_1.PNG") },
                            .default(Text("加载测试图片2 (不二君)")) { loadTestImage(name: "sample_bill_2.PNG") },
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
                                self.selectedType = transaction.type // 先更新类型
                                // 根据OCR识别的类型，从viewModel获取对应的分类和支付方式列表，并尝试匹配
                                // 如果OCR结果中的分类/支付方式不在对应列表，则选择列表的第一个作为默认值
                                if viewModel.categories(for: transaction.type).contains(transaction.category) {
                                    self.category = transaction.category
                                } else {
                                    self.category = viewModel.categories(for: transaction.type).first ?? ""
                                }
                                if viewModel.paymentMethods(for: transaction.type).contains(transaction.paymentMethod) {
                                    self.paymentMethod = transaction.paymentMethod
                                } else {
                                    self.paymentMethod = viewModel.paymentMethods(for: transaction.type).first ?? ""
                                }
                                self.note = transaction.note
                            }
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return
        }
        
        let transaction = Transaction(
            amount: amountValue,
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
        category = viewModel.categories(for: .expense).first ?? "" 
        paymentMethod = viewModel.paymentMethods(for: .expense).first ?? ""
        note = ""
        inputImage = nil // 重置时也清空选择的图片
    }
    
    // 新增方法：加载项目内的测试图片
    private func loadTestImage(name: String) {
        if let testImage = UIImage(named: name) {
            self.inputImage = testImage
        } else {
            print("测试图片 \(name) 加载失败")
            // 可以考虑在这里给用户一些提示，比如弹出一个Alert
        }
    }
}

// 预览
#Preview {
    TransactionFormView(viewModel: TransactionViewModel())
}
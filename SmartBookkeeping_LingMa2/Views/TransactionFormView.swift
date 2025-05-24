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
    @State private var inputImage: UIImage?
    private let ocrService = OCRService()
    
    // 分类选项
    private let categories = ["请选择分类"]
    private let paymentMethods = ["请选择"]
    
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
                        ForEach(categories, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
                        ForEach(paymentMethods, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
                    Button("上传数据（请选择图像来源）") {
                        showingImagePicker = true
                    }
                    .sheet(isPresented: $showingImagePicker) {
                        ImagePicker(image: $inputImage)
                    }
                    .onChange(of: inputImage) { newValue in
                        guard let selectedImage = newValue else { return }
                        ocrService.recognizeText(from: selectedImage) { transaction in
                            if let transaction = transaction {
                                self.amount = String(format: "%.2f", transaction.amount)
                                self.date = transaction.date
                                self.description = transaction.description
                                self.category = transaction.category
                                self.selectedType = transaction.type
                                self.paymentMethod = transaction.paymentMethod
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
        category = ""
        selectedType = .expense
        paymentMethod = ""
        note = ""
    }
}

// 预览
#Preview {
    TransactionFormView(viewModel: TransactionViewModel())
}
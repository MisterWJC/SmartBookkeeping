//
//  TransactionEditView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/27.
//

import SwiftUI
import Combine

struct TransactionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransactionViewModel
    
    let transaction: Transaction
    
    @State private var amount: String
    @State private var date: Date
    @State private var category: String
    @State private var description: String
    @State private var type: Transaction.TransactionType
    @State private var paymentMethod: String
    @State private var note: String
    
    @State private var showingDeleteAlert = false
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _amount = State(initialValue: String(format: "%.2f", transaction.amount))
        _date = State(initialValue: transaction.date)
        _category = State(initialValue: transaction.category)
        _description = State(initialValue: transaction.description)
        _type = State(initialValue: transaction.type)
        _paymentMethod = State(initialValue: transaction.paymentMethod)
        _note = State(initialValue: transaction.note)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        VStack(spacing: 20) {
                        // 基本信息部分
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("基本信息")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGroupedBackground))
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("金额")
                                    Spacer()
                                    TextField("0.00", text: $amount)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemBackground))
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                HStack {
                                    Text("交易类型")
                                    Spacer()
                                    Picker("交易类型", selection: $type) {
                                        ForEach(Transaction.TransactionType.allCases, id: \.self) { transactionType in
                                            Text(transactionType.rawValue).tag(transactionType)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .onChange(of: type) { newType in
                                    updateCategoryForType(newType)
                                }
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                HStack {
                                    Text("交易分类")
                                    Spacer()
                                    Picker("交易分类", selection: $category) {
                                        ForEach(categoriesForSelectedType, id: \.self) { category in
                                            Text(category).tag(category)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                HStack {
                                    Text("收/付款方式")
                                    Spacer()
                                    Picker("付款方式", selection: $paymentMethod) {
                                        ForEach(CategoryDataManager.shared.paymentMethods, id: \.self) { method in
                                            Text(method).tag(method)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                        }
                        
                        // 商品明细部分
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("商品明细")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGroupedBackground))
                            
                            TextField("请输入商品明细", text: $description)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .padding(.horizontal, 16)
                        }
                        
                        // 备注部分
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("备注")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGroupedBackground))
                            
                            TextField("请输入备注信息", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .padding(.horizontal, 16)
                        }
                        
                        // 添加底部间距，为删除按钮和键盘留出空间
                        Spacer(minLength: 200)
                    }
                    .padding(.vertical, 20)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .keyboardAdaptive()
            .navigationTitle("编辑交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveTransaction()
                    }
                    .disabled(!isValidInput)
                }
            }
        .overlay(
            VStack {
                Spacer()
                Button("删除交易") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator)),
                    alignment: .top
                )
            })
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("确定要删除这条交易记录吗？此操作无法撤销。")
        }
    }
}
    
    private var categoriesForSelectedType: [String] {
        CategoryDataManager.shared.categories(for: type)
    }
    
    private var isValidInput: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func updateCategoryForType(_ newType: Transaction.TransactionType) {
        let availableCategories = CategoryDataManager.shared.categories(for: newType)
        if !availableCategories.contains(category) {
            category = availableCategories.first ?? "其他"
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        let updatedTransaction = Transaction(
            id: transaction.id,
            amount: amountValue,
            date: date,
            category: category,
            description: description,
            type: type,
            paymentMethod: paymentMethod,
            note: note
        )
        
        viewModel.updateTransaction(updatedTransaction)
        dismiss()
    }
    
    private func deleteTransaction() {
        viewModel.deleteTransaction(transaction: transaction)
        dismiss()
    }
}

// MARK: - Keyboard Adaptive Extension
extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(Publishers.keyboardHeight) { height in
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = height
                }
            }
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

#Preview {
    let sampleTransaction = Transaction(
        amount: 38.00,
        date: Date(),
        category: "餐饮美食",
        description: "午餐",
        type: .expense,
        paymentMethod: "微信",
        note: "和同事一起吃饭"
    )
    
    return TransactionEditView(transaction: sampleTransaction)
        .environmentObject(TransactionViewModel(context: PersistenceController.preview.container.viewContext))
}
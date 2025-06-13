//
//  CategoryManagementView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI
import CoreData

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedSegment = 0 // 0: 分类管理, 1: 付款方式管理
    @State private var selectedTransactionType: Transaction.TransactionType = .expense
    @State private var newCategoryName = ""
    @State private var newPaymentMethodName = ""
    @State private var showingAddCategoryAlert = false
    @State private var showingAddPaymentMethodAlert = false
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: String = ""
    
    @FetchRequest private var categories: FetchedResults<CategoryItem>
    @FetchRequest private var paymentMethods: FetchedResults<PaymentMethodItem>
    
    private let categoryManager = CategoryDataManager.shared
    
    init() {
        // 初始化分类的 FetchRequest
        self._categories = FetchRequest<CategoryItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CategoryItem.sortOrder, ascending: true)],
            predicate: NSPredicate(format: "type == %@", "expense")
        )
        
        // 初始化付款方式的 FetchRequest
        self._paymentMethods = FetchRequest<PaymentMethodItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \PaymentMethodItem.sortOrder, ascending: true)]
        )
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 顶部分段控制器
                Picker("管理类型", selection: $selectedSegment) {
                    Text("分类管理").tag(0)
                    Text("付款方式").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedSegment == 0 {
                    categoryManagementView
                } else {
                    paymentMethodManagementView
                }
            }
            .navigationTitle("数据管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        if selectedSegment == 0 {
                            showingAddCategoryAlert = true
                        } else {
                            showingAddPaymentMethodAlert = true
                        }
                    }
                }
            }
        }
        .alert("添加分类", isPresented: $showingAddCategoryAlert) {
            TextField("分类名称", text: $newCategoryName)
            Button("取消", role: .cancel) {
                newCategoryName = ""
            }
            Button("添加") {
                addCategory()
            }
        } message: {
            Text("请输入新的\(selectedTransactionType == .expense ? "支出" : "收入")分类名称")
        }
        .alert("添加付款方式", isPresented: $showingAddPaymentMethodAlert) {
            TextField("付款方式名称", text: $newPaymentMethodName)
            Button("取消", role: .cancel) {
                newPaymentMethodName = ""
            }
            Button("添加") {
                addPaymentMethod()
            }
        } message: {
            Text("请输入新的付款方式名称")
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("确定要删除 \"\(itemToDelete)\" 吗？此操作无法撤销。")
        }
        .onChange(of: selectedTransactionType) { _ in
            updateCategoriesFetchRequest()
        }
    }
    
    // 分类管理视图
    private var categoryManagementView: some View {
        VStack {
            // 交易类型选择
            Picker("交易类型", selection: $selectedTransactionType) {
                Text("支出").tag(Transaction.TransactionType.expense)
                Text("收入").tag(Transaction.TransactionType.income)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // 分类列表
            List {
                ForEach(categories, id: \.id) { category in
                    HStack {
                        Text(category.name ?? "未知分类")
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            if category.isDefault {
                                Text("默认")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                            
                            Button("删除") {
                                itemToDelete = category.name ?? ""
                                showingDeleteAlert = true
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }
    
    // 付款方式管理视图
    private var paymentMethodManagementView: some View {
        List {
            ForEach(paymentMethods, id: \.id) { method in
                HStack {
                    Text(method.name ?? "未知付款方式")
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if method.isDefault {
                            Text("默认")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        Button("删除") {
                            itemToDelete = method.name ?? ""
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    // 添加分类
    private func addCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        categoryManager.addCategory(name: trimmedName, type: selectedTransactionType)
        newCategoryName = ""
    }
    
    // 添加付款方式
    private func addPaymentMethod() {
        let trimmedName = newPaymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        categoryManager.addPaymentMethod(name: trimmedName)
        newPaymentMethodName = ""
    }
    
    // 确认删除
    private func confirmDelete() {
        if selectedSegment == 0 {
            deleteCategory(itemToDelete)
        } else {
            deletePaymentMethod(itemToDelete)
        }
        itemToDelete = ""
    }
    
    // 删除分类
    private func deleteCategory(_ name: String) {
        let request: NSFetchRequest<CategoryItem> = CategoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        do {
            let items = try viewContext.fetch(request)
            for item in items {
                viewContext.delete(item)
            }
            try viewContext.save()
            // 通知数据变化
            DispatchQueue.main.async {
                CategoryDataManager.shared.categoriesDidChange.toggle()
            }
        } catch {
            print("删除分类失败: \(error)")
        }
    }
    
    // 删除付款方式
    private func deletePaymentMethod(_ name: String) {
        let request: NSFetchRequest<PaymentMethodItem> = PaymentMethodItem.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        do {
            let items = try viewContext.fetch(request)
            for item in items {
                viewContext.delete(item)
            }
            try viewContext.save()
            // 通知数据变化
            DispatchQueue.main.async {
                CategoryDataManager.shared.paymentMethodsDidChange.toggle()
            }
        } catch {
            print("删除付款方式失败: \(error)")
        }
    }
    
    // 更新分类的 FetchRequest
    private func updateCategoriesFetchRequest() {
        let typeString = selectedTransactionType == .income ? "income" : "expense"
        categories.nsPredicate = NSPredicate(format: "type == %@", typeString)
    }
}

#Preview {
    CategoryManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
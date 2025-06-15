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
    @State private var selectedCategoryIcon = "folder"
    @State private var showingAddCategoryAlert = false
    @State private var showingAddCategorySheet = false
    @State private var showingAddPaymentMethodAlert = false
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: String = ""
    @State private var showingAccountEdit = false
    
    // 可选择的分类图标
    private let categoryIcons = [
        "folder", "cart", "house", "car", "airplane", "gamecontroller",
        "book", "heart", "gift", "creditcard", "bag", "tshirt",
        "fork.knife", "cup.and.saucer", "pills", "stethoscope", "graduationcap", "briefcase"
    ]
    
    // 更丰富的图标选择（照搬AddCategoryView的实现）
    private let availableIcons = [
        "fork.knife", "laptopcomputer", "book.fill", "tshirt.fill", "cart.fill",
        "car.fill", "gamecontroller.fill", "cross.fill", "house.fill", "creditcard.fill",
        "phone.fill", "wifi", "bolt.fill", "drop.fill", "flame.fill",
        "leaf.fill", "heart.fill", "star.fill", "moon.fill", "sun.max.fill",
        "cloud.fill", "umbrella.fill", "gift.fill", "bag.fill", "briefcase.fill",
        "graduationcap.fill", "stethoscope", "scissors", "hammer.fill", "wrench.fill",
        "paintbrush.fill", "camera.fill", "music.note", "headphones", "tv.fill",
        "airplane", "bicycle", "bus.fill", "train.side.front.car", "ferry.fill",
        "fuelpump.fill", "parkingsign", "figure.walk", "figure.run", "sportscourt.fill",
        "dumbbell.fill", "tennis.racket", "football.fill", "basketball.fill", "baseball.fill",
        "tag.fill", "folder.fill", "doc.fill", "calendar", "clock.fill"
    ]
    
    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var transactionViewModel: TransactionViewModel
    
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
        
        // 初始化TransactionViewModel
        self._transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: PersistenceController.shared.container.viewContext))
    }
    
    // 获取TransactionItem数据的辅助方法
    private func getTransactionItems() -> [TransactionItem] {
        let request: NSFetchRequest<TransactionItem> = TransactionItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionItem.date, ascending: false)]
        
        do {
            return try transactionViewModel.managedObjectContext.fetch(request)
        } catch {
            print("获取TransactionItem数据失败: \(error.localizedDescription)")
            return []
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 顶部分段控制器
                Picker("管理类型", selection: $selectedSegment) {
                    Text("分类管理").tag(0)
                    Text("收/付款方式").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedSegment == 0 {
                    categoryManagementView
                } else {
                    paymentMethodManagementView
                }
            }
            .navigationTitle("自定义交易分类和账户")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSegment == 0 {
                        Button("添加") {
                            showingAddCategorySheet = true
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
        .sheet(isPresented: $showingAccountEdit) {
            NavigationView {
                AccountEditView(
                    account: nil,
                    transactionViewModel: transactionViewModel
                )
            }
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            addCategorySheet
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
                        // 分类图标
                        Image(systemName: category.icon ?? "folder")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
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
        VStack {
            // 添加账户按钮
            Button(action: {
                showingAccountEdit = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加新账户")
                }
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // 收/付款方式列表（显示所有账户）
            List {
                ForEach(accountViewModel.accounts, id: \.id) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.name ?? "未知账户")
                                .font(.body)
                            Text(String(format: "余额: %.2f", accountViewModel.calculateCurrentBalance(for: account, transactions: getTransactionItems())))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            if account.isDefault {
                                Text("默认")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                            
                            Button("删除") {
                                itemToDelete = account.name ?? ""
                                showingDeleteAlert = true
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // 添加分类Sheet界面
    private var addCategorySheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题
                Text("添加新分类")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                // 分类名称输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("分类名称")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("请输入分类名称", text: $newCategoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                .padding(.horizontal)
                
                // 图标选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择图标")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    // 当前选中的图标预览
                    HStack {
                        Image(systemName: selectedCategoryIcon)
                            .font(.title)
                            .foregroundColor(iconColor(for: selectedCategoryIcon))
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("当前选中")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 图标网格
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedCategoryIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(iconColor(for: icon))
                                        .frame(width: 44, height: 44)
                                        .background(selectedCategoryIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedCategoryIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // 底部按钮
                HStack(spacing: 16) {
                    Button("取消") {
                        newCategoryName = ""
                        selectedCategoryIcon = "folder"
                        showingAddCategorySheet = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    
                    Button("添加") {
                        addCategory()
                        showingAddCategorySheet = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
    
    // 添加分类
    private func addCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        categoryManager.addCategory(name: trimmedName, icon: selectedCategoryIcon, type: selectedTransactionType)
        newCategoryName = ""
        selectedCategoryIcon = "folder"
        showingAddCategorySheet = false
        
        // 刷新分类列表
        updateCategoriesFetchRequest()
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
            deleteAccount(itemToDelete)
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
    
    // 删除账户
    private func deleteAccount(_ name: String) {
        accountViewModel.deleteAccount(name: name)
    }
    
    // 更新分类的 FetchRequest
    private func updateCategoriesFetchRequest() {
        let typeString = selectedTransactionType == .income ? "income" : "expense"
        categories.nsPredicate = NSPredicate(format: "type == %@", typeString)
    }
    
    // 图标颜色方法（照搬AddCategoryView的实现）
    private func iconColor(for icon: String) -> Color {
        // 根据图标类型返回不同颜色
        switch icon {
        case "fork.knife":
            return .orange
        case "laptopcomputer", "phone.fill", "wifi", "tv.fill", "camera.fill":
            return .blue
        case "book.fill", "graduationcap.fill":
            return .purple
        case "tshirt.fill", "bag.fill":
            return .pink
        case "cart.fill", "leaf.fill":
            return .green
        case "car.fill", "airplane", "bicycle", "bus.fill", "train.side.front.car":
            return .red
        case "gamecontroller.fill", "music.note", "headphones":
            return .yellow
        case "cross.fill", "stethoscope":
            return .red
        case "house.fill":
            return .brown
        case "creditcard.fill":
            return .cyan
        case "heart.fill":
            return .red
        case "star.fill", "sun.max.fill":
            return .yellow
        case "moon.fill":
            return .indigo
        case "cloud.fill", "drop.fill":
            return .blue
        case "flame.fill", "bolt.fill":
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    CategoryManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
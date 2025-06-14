//
//  InitialSetupView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI

struct InitialSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var customExpenseCategories: [String] = []
    @State private var customIncomeCategories: [String] = []
    @State private var customAccounts: [(name: String, type: AccountType, balance: Double)] = []
    @State private var newCategoryName = ""
    @State private var selectedTransactionType: Transaction.TransactionType = .expense
    @State private var removedDefaultExpenseCategories: Set<String> = []
    @State private var removedDefaultIncomeCategories: Set<String> = []
    @State private var removedDefaultAccounts: Set<String> = []
    @State private var showingAccountEdit = false
    @State private var apiKey: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let categoryManager = CategoryDataManager.shared
    private let configManager = ConfigurationManager.shared
    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var transactionViewModel = TransactionViewModel(context: PersistenceController.shared.container.viewContext)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 进度指示器
                ProgressView(value: Double(currentStep), total: 3)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                
                // 步骤内容
                TabView(selection: $currentStep) {
                    // 第一步：设置分类
                    categorySetupView
                        .tag(0)
                    
                    // 第二步：设置账户
                    accountSetupView
                        .tag(1)
                    
                    // 第三步：API配置
                    apiSetupView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 底部按钮
                HStack {
                    if currentStep > 0 {
                        Button("上一步") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == 2 ? "完成设置" : "下一步") {
                        if currentStep == 2 {
                            completeSetup()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .navigationTitle("初始设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAccountEdit) {
                AccountEditView(
                    account: nil, 
                    transactionViewModel: transactionViewModel,
                    onAccountCreated: { name, type, balance in
                        // 添加新账户到customAccounts数组
                        customAccounts.append((name: name, type: type, balance: balance))
                        showingAccountEdit = false
                    }
                )
            }
        }
    }
    
    
    // 分类设置视图
    private var categorySetupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("设置交易分类")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("我们已为您预设了常用分类，您也可以添加自定义分类")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 交易类型选择
            Picker("交易类型", selection: $selectedTransactionType) {
                Text("支出").tag(Transaction.TransactionType.expense)
                Text("收入").tag(Transaction.TransactionType.income)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 默认分类列表
            VStack(alignment: .leading, spacing: 12) {
                Text("默认分类")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableDefaultCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button(action: {
                                removeDefaultCategory(category)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            // 添加自定义分类
            VStack(alignment: .leading, spacing: 12) {
                Text("自定义分类")
                    .font(.headline)
                
                HStack {
                    TextField("输入分类名称", text: $newCategoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("添加") {
                        addCustomCategory()
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if !currentCustomCategories.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(currentCustomCategories, id: \.self) { category in
                            HStack {
                                Text(category)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                Button(action: {
                                    removeCustomCategory(category)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            }
            .padding()
        }

    
    // 账户设置视图
    private var accountSetupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("设置账户")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("我们已为您预设了常用账户，您也可以添加自定义账户")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 默认账户列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("默认账户")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                        ForEach(availableDefaultAccounts, id: \.self) { account in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(getAccountTypeText(for: account))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                                
                                Spacer()
                                
                                Button(action: {
                                    removeDefaultAccount(account)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // 添加新账户
                VStack(alignment: .leading, spacing: 12) {
                    Text("自定义账户")
                        .font(.headline)
                    
                    Button("添加新账户") {
                        showingAccountEdit = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    if !customAccounts.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                            ForEach(customAccounts.indices, id: \.self) { index in
                                let account = customAccounts[index]
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(account.name)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        HStack {
                                            Text(account.type == .asset ? "资产账户" : "负债账户")
                                                .font(.caption)
                                            Spacer()
                                            Text(String(format: "%.2f", account.balance))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        removeCustomAccount(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
    
    // 添加自定义分类
    private func addCustomCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if selectedTransactionType == .expense {
            customExpenseCategories.append(trimmedName)
        } else {
            customIncomeCategories.append(trimmedName)
        }
        newCategoryName = ""
    }
    
    // 移除自定义分类
    private func removeCustomCategory(_ category: String) {
        if selectedTransactionType == .expense {
            customExpenseCategories.removeAll { $0 == category }
        } else {
            customIncomeCategories.removeAll { $0 == category }
        }
    }
    
    // 移除默认分类
    private func removeDefaultCategory(_ category: String) {
        if selectedTransactionType == .expense {
            removedDefaultExpenseCategories.insert(category)
        } else {
            removedDefaultIncomeCategories.insert(category)
        }
    }
    
    // 添加新账户
    private func addNewAccount() {
        // 创建一个默认的新账户
        let accountName = "新账户\(customAccounts.count + 1)"
        let initialBalance = 0.0
        let accountType = AccountType.asset
        
        // 直接保存到后台
        accountViewModel.createAccount(
            name: accountName,
            initialBalance: initialBalance,
            balanceDate: Date(),
            accountType: accountType.rawValue,
            includeInAssets: accountType == .asset,
            note: "",
            isDefault: false
        )
        
        // 同时添加到本地数组用于显示
        let newAccount = (name: accountName, type: accountType, balance: initialBalance)
        customAccounts.append(newAccount)
    }
    
    // 移除自定义账户
    private func removeCustomAccount(at index: Int) {
        let accountToRemove = customAccounts[index]
        // 从数据库中删除账户
        accountViewModel.deleteAccount(name: accountToRemove.name)
        // 从本地数组中移除
        customAccounts.remove(at: index)
    }
    
    // 移除默认账户
    private func removeDefaultAccount(_ account: String) {
        removedDefaultAccounts.insert(account)
    }
    
    // 计算当前交易类型的自定义分类
    private var currentCustomCategories: [String] {
        return selectedTransactionType == .expense ? customExpenseCategories : customIncomeCategories
    }
    
    // 计算可用的默认分类
    private var availableDefaultCategories: [String] {
        let removedCategories = selectedTransactionType == .expense ? removedDefaultExpenseCategories : removedDefaultIncomeCategories
        return categoryManager.categories(for: selectedTransactionType).filter { !removedCategories.contains($0) }
    }
    
    // 计算可用的默认账户
    private var availableDefaultAccounts: [String] {
        return categoryManager.defaultAccountsData.map { $0.0 }.filter { !removedDefaultAccounts.contains($0) }
    }
    
    // 获取账户类型文本
    private func getAccountTypeText(for accountName: String) -> String {
        if let accountData = categoryManager.defaultAccountsData.first(where: { $0.0 == accountName }) {
            return accountData.1 == "资产" ? "资产账户" : "负债账户"
        }
        return "资产账户"
    }
    
    // API设置视图
    private var apiSetupView: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("配置AI功能")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("为了使用AI智能识别功能，请配置智谱AI API密钥")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("API密钥")
                    .font(.headline)
                
                SecureField("请输入智谱AI API密钥", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("如何获取API密钥：")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("1. 访问 https://open.bigmodel.cn")
                    Text("2. 注册并登录账户")
                    Text("3. 在控制台创建API密钥")
                    Text("4. 复制密钥并粘贴到上方输入框")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            HStack {
                Button("跳过") {
                    completeSetup()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存并完成") {
                    saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            Spacer()
        }
        .padding()
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // 保存API密钥
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            alertMessage = "请输入有效的API密钥"
            showAlert = true
            return
        }
        
        configManager.setAPIConfiguration(apiKey: trimmedKey)
        alertMessage = "API密钥保存成功"
        showAlert = true
        
        // 延迟完成设置，让用户看到成功提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completeSetup()
        }
    }
    
    // 完成设置
    private func completeSetup() {
        // 保存所有自定义支出分类
        for category in customExpenseCategories {
            categoryManager.addCategory(name: category, type: .expense)
        }
        
        // 保存所有自定义收入分类
        for category in customIncomeCategories {
            categoryManager.addCategory(name: category, type: .income)
        }
        
        // 删除被移除的默认账户
        for accountName in removedDefaultAccounts {
            accountViewModel.deleteAccount(name: accountName)
        }
        
        // 自定义账户已经在添加时直接保存，这里不需要重复保存
        
        categoryManager.markInitialSetupCompleted()
        dismiss()
    }
}

#Preview {
    InitialSetupView()
}

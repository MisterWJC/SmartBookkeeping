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
    @State private var customPaymentMethods: [String] = []
    @State private var newCategoryName = ""
    @State private var newPaymentMethodName = ""
    @State private var selectedTransactionType: Transaction.TransactionType = .expense
    @State private var removedDefaultExpenseCategories: Set<String> = []
    @State private var removedDefaultIncomeCategories: Set<String> = []
    @State private var removedDefaultPaymentMethods: Set<String> = []
    
    private let categoryManager = CategoryDataManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 进度指示器
                ProgressView(value: Double(currentStep), total: 2)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                
                // 步骤内容
                TabView(selection: $currentStep) {
                    // 第一步：设置分类
                    categorySetupView
                        .tag(0)
                    
                    // 第二步：设置付款方式
                    paymentMethodSetupView
                        .tag(1)
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
                    
                    Button(currentStep == 1 ? "完成设置" : "下一步") {
                        if currentStep == 1 {
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
    
    // 付款方式设置视图
    private var paymentMethodSetupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("设置付款方式")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("我们已为您预设了常用付款方式，您也可以添加自定义付款方式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 默认付款方式列表
            VStack(alignment: .leading, spacing: 12) {
                Text("默认付款方式")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableDefaultPaymentMethods, id: \.self) { method in
                        HStack {
                            Text(method)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button(action: {
                                removeDefaultPaymentMethod(method)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            // 添加自定义付款方式
            VStack(alignment: .leading, spacing: 12) {
                Text("自定义付款方式")
                    .font(.headline)
                
                HStack {
                    TextField("输入付款方式名称", text: $newPaymentMethodName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("添加") {
                        addCustomPaymentMethod()
                    }
                    .disabled(newPaymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if !customPaymentMethods.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(customPaymentMethods, id: \.self) { method in
                            HStack {
                                Text(method)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                Button(action: {
                                    removeCustomPaymentMethod(method)
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
    
    // 添加自定义付款方式
    private func addCustomPaymentMethod() {
        let trimmedName = newPaymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        customPaymentMethods.append(trimmedName)
        newPaymentMethodName = ""
    }
    
    // 移除自定义付款方式
    private func removeCustomPaymentMethod(_ method: String) {
        customPaymentMethods.removeAll { $0 == method }
    }
    
    // 移除默认付款方式
    private func removeDefaultPaymentMethod(_ method: String) {
        removedDefaultPaymentMethods.insert(method)
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
    
    // 计算可用的默认付款方式
    private var availableDefaultPaymentMethods: [String] {
        return categoryManager.paymentMethods(for: .expense).filter { !removedDefaultPaymentMethods.contains($0) }
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
        
        // 保存所有自定义付款方式
        for paymentMethod in customPaymentMethods {
            categoryManager.addPaymentMethod(name: paymentMethod)
        }
        
        categoryManager.markInitialSetupCompleted()
        dismiss()
    }
}

#Preview {
    InitialSetupView()
}
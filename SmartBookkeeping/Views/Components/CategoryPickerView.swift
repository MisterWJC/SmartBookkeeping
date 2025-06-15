//
//  CategoryPickerView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: String
    let transactionType: Transaction.TransactionType
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var selectedIcon = "tag.fill"
    @State private var categories: [String] = []
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryManager = CategoryDataManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择分类")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                // 分类列表
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(categories, id: \.self) { category in
                            CategoryRow(
                                category: category,
                                isSelected: selectedCategory == category
                            )
                            .onTapGesture {
                                selectedCategory = category
                                dismiss()
                            }
                        }
                        
                        // 添加新分类按钮
                        Button(action: {
                            showingAddCategory = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                Text("添加新分类")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 底部按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("完成")
                        .frame(maxWidth: .infinity) // 将所有修饰符移到 Text 上
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(
                categoryName: $newCategoryName,
                selectedIcon: $selectedIcon,
                transactionType: transactionType
            ) { name, icon in
                addNewCategory(name: name, icon: icon)
            }
        }
        .onAppear {
            loadCategories()
        }
    }
    
    private func loadCategories() {
        categories = categoryManager.getCategories(for: transactionType)
    }
    
    private func addNewCategory(name: String, icon: String) {
        categoryManager.addCategory(name: name, icon: icon, type: transactionType)
        loadCategories()
        selectedCategory = name
        newCategoryName = ""
        selectedIcon = "tag.fill"
        // 不立即关闭picker，让用户可以看到新添加的分类并进行选择
    }
}

struct CategoryRow: View {
    let category: String
    let isSelected: Bool
    @StateObject private var categoryManager = CategoryDataManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: getCategoryIcon())
                .foregroundColor(categoryColor(for: getCategoryIcon()))
                .font(.title2)
                .frame(width: 30)
            
            Text(category)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.body)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isSelected ? categoryColor(for: getCategoryIcon()).opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getCategoryIcon() -> String {
        // 从Core Data获取图标，如果没有则使用默认图标
        return categoryIcon(for: category)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "餐饮美食":
            return "fork.knife"
        case "数码电器":
            return "laptopcomputer"
        case "自我提升":
            return "book.fill"
        case "服装饰品":
            return "tshirt.fill"
        case "日用百货":
            return "cart.fill"
        case "车辆交通":
            return "car.fill"
        case "娱乐休闲":
            return "gamecontroller.fill"
        case "医疗健康":
            return "cross.fill"
        case "家庭支出":
            return "house.fill"
        case "充值缴费":
            return "creditcard.fill"
        default:
            return "tag.fill"
        }
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category {
        case "餐饮美食":
            return .orange
        case "数码电器":
            return .blue
        case "自我提升":
            return .purple
        case "服装饰品":
            return .pink
        case "日用百货":
            return .green
        case "车辆交通":
            return .red
        case "娱乐休闲":
            return .yellow
        case "医疗健康":
            return .red
        case "家庭支出":
            return .brown
        case "充值缴费":
            return .cyan
        default:
            return .gray
        }
    }
}

#Preview {
    CategoryPickerView(selectedCategory: .constant("餐饮美食"), transactionType: .expense)
}
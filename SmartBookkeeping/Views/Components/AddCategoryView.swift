//
//  AddCategoryView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI

struct AddCategoryView: View {
    @Binding var categoryName: String
    @Binding var selectedIcon: String
    let transactionType: Transaction.TransactionType
    let onSave: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempName = ""
    @State private var tempIcon = "tag.fill"
    
    // 可选择的图标列表
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
    
    var body: some View {
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
                    
                    TextField("请输入分类名称", text: $tempName)
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
                        Image(systemName: tempIcon)
                            .font(.title)
                            .foregroundColor(iconColor(for: tempIcon))
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
                                    tempIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(iconColor(for: icon))
                                        .frame(width: 44, height: 44)
                                        .background(tempIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(tempIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
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
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    
                    Button("添加") {
                        let trimmedName = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            onSave(trimmedName, tempIcon)
                            dismiss() // 关闭AddCategoryView，回到CategoryPickerView
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            tempName = categoryName
            tempIcon = selectedIcon
        }
    }
    
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
    AddCategoryView(
        categoryName: .constant(""),
        selectedIcon: .constant("tag.fill"),
        transactionType: .expense
    ) { _, _ in }
}
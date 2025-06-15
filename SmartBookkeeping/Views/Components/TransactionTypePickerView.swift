//
//  TransactionTypePickerView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI

struct TransactionTypePickerView: View {
    @Binding var selectedType: Transaction.TransactionType
    let onSave: (Transaction.TransactionType) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempType: Transaction.TransactionType = .expense
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择交易类型")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // 收入选项
                    Button(action: {
                        tempType = .income
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            Text("收入")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if tempType == .income {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(tempType == .income ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 支出选项
                    Button(action: {
                        tempType = .expense
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            
                            Text("支出")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if tempType == .expense {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(tempType == .expense ? Color.red.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("取消") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    
                    Button("确认") {
                        onSave(tempType)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            tempType = selectedType
        }
    }
}

#Preview {
    TransactionTypePickerView(selectedType: .constant(.expense)) { _ in }
}
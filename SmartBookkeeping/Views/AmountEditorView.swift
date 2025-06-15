//
//  AmountEditorView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2024/01/01.
//

import SwiftUI

struct AmountEditorView: View {
    @Binding var amount: String
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempAmount: String = ""
    @State private var validationError: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("编辑金额")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("金额")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("¥")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        TextField("0.00", text: $tempAmount)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: tempAmount) { _ in
                                validateAmount()
                            }
                    }
                }
                .padding(.horizontal)
                
                // 验证错误提示
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
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
                    
                    Button("保存") {
                        if validateAmount() {
                            onSave(tempAmount)
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(validationError == nil && !tempAmount.isEmpty ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(validationError != nil || tempAmount.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            tempAmount = amount
            validateAmount()
        }
    }
    
    @discardableResult
    private func validateAmount() -> Bool {
        let result = ValidationUtils.validateAmount(tempAmount)
        validationError = result.errorMessage
        return result.isValid
    }
}

#Preview {
    AmountEditorView(amount: .constant("24.50")) { _ in }
}
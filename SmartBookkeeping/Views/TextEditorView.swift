//
//  TextEditorView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2024/01/01.
//

import SwiftUI

struct TextEditorView: View {
    let title: String
    @Binding var text: String
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $tempText)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(minHeight: 120)
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
                    
                    Button("保存") {
                        onSave(tempText)
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
            tempText = text
        }
    }
}

#Preview {
    TextEditorView(
        title: "编辑备注",
        text: .constant("示例文本")
    ) { _ in }
}
//
//  ClickableTagRow.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI

struct ClickableTagRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let confidence: Double? // AI置信度，0.0-1.0
    let action: () -> Void
    
    // 置信度阈值
    private let lowConfidenceThreshold: Double = 0.7
    
    // 是否为低置信度项目
    private var isLowConfidence: Bool {
        guard let confidence = confidence else { return false }
        return confidence < lowConfidenceThreshold
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                Spacer()
                
HStack(spacing: 8) {
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isLowConfidence ? .orange : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background((isLowConfidence ? Color.orange : Color.blue).opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isLowConfidence ? 
                                    Color.orange.opacity(0.5) : 
                                    Color.blue.opacity(0.3),
                                    style: isLowConfidence ? 
                                    StrokeStyle(lineWidth: 2, dash: [5, 3]) : 
                                    StrokeStyle(lineWidth: 1)
                                )
                        )
                    
                    // 低置信度提示图标
                    if isLowConfidence {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
VStack {
        ClickableTagRow(
            icon: "dollarsign.circle.fill",
            title: "金额",
            value: "24.50",
            color: .green,
            confidence: 0.9
        ) {
            print("点击金额")
        }
        
        ClickableTagRow(
            icon: "tag.fill",
            title: "分类",
            value: "餐饮美食",
            color: .blue,
            confidence: 0.5
        ) {
            print("点击分类")
        }
    }
    .padding()
}
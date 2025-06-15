//
//  DatePickerView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2024/01/01.
//

import SwiftUI

struct DatePickerView: View {
    @Binding var selectedDate: Date
    let onSave: (Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempDate: Date = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择交易时间")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("交易时间")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    DatePicker(
                        "选择日期和时间",
                        selection: $tempDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
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
                        onSave(tempDate)
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
            tempDate = selectedDate
        }
    }
}

#Preview {
    DatePickerView(selectedDate: .constant(Date())) { _ in }
}
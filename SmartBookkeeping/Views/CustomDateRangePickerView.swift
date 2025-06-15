//
//  CustomDateRangePickerView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct CustomDateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择时间范围")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("开始日期")
                            .font(.headline)
                            .foregroundColor(.primary)
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("结束日期")
                            .font(.headline)
                            .foregroundColor(.primary)
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                }
                .padding(.horizontal)
                
                // 快捷选择按钮
                VStack(spacing: 10) {
                    Text("快捷选择")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        quickSelectButton("最近7天") {
                            endDate = Date()
                            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
                        }
                        
                        quickSelectButton("最近30天") {
                            endDate = Date()
                            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
                        }
                        
                        quickSelectButton("本月") {
                            let calendar = Calendar.current
                            let now = Date()
                            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
                            endDate = calendar.dateInterval(of: .month, for: now)?.end ?? now
                        }
                        
                        quickSelectButton("上月") {
                            let calendar = Calendar.current
                            let now = Date()
                            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                            startDate = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth
                            endDate = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? lastMonth
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 确认和取消按钮
                HStack(spacing: 20) {
                    Button("取消") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    Button("确认") {
                        // 确保开始日期不晚于结束日期
                        if startDate > endDate {
                            let temp = startDate
                            startDate = endDate
                            endDate = temp
                        }
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func quickSelectButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
    }
}

struct CustomDateRangePickerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomDateRangePickerView(
            startDate: .constant(Date()),
            endDate: .constant(Date()),
            isPresented: .constant(true)
        )
    }
}
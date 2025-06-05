//
//  ChartView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct ChartView: View {
    @ObservedObject var viewModel: TransactionViewModel

    // 显式声明 internal init，尽管这是默认的
    internal init(viewModel: TransactionViewModel) {
        self.viewModel = viewModel
    }
    
    @State private var selectedMonth: String = "全部月份"

    // data 现在是一个计算属性，依赖于 selectedMonth
    private var chartData: [String: Double] {
        viewModel.getTransactionTypeDistribution(forMonth: selectedMonth)
    }
    
    private var total: Double {
        chartData.values.reduce(0, +)
    }
    
    private var colors: [Color] = [.blue, .green, .orange, .red] // 可以根据需要扩展颜色
    
    var body: some View {
        VStack {
            // 月份选择器
            Picker("选择月份", selection: $selectedMonth) {
                ForEach(viewModel.getAllMonths(), id: \.self) { month in
                    Text(month)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            Spacer() 
            
            if total > 0 { // 仅当有数据时显示饼图和图例
                ZStack {
                    PieChartView(data: chartData, colors: colors)
                        .frame(width: 200, height: 200) 
                        .padding()
                }
                
                HStack(spacing: 20) {
                    ForEach(Array(chartData.keys.enumerated()), id: \.element) { index, key in
                        if index < colors.count, chartData[key] ?? 0 > 0 {
                            HStack {
                                Circle()
                                    .fill(colors[index % colors.count]) 
                                    .frame(width: 10, height: 10)
                                Text("\(key): \(chartData[key] ?? 0, specifier: "%.2f")") 
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.top)
            } else {
                Text("当前选择月份无数据")
                    .foregroundColor(.secondary)
            }
            
            Spacer() 
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) 
        .onAppear {
            // 初始化时，如果 viewModel.getAllMonths() 不为空，则设置 selectedMonth 为第一个月（通常是“全部月份”或最近的月份）
            if let firstMonth = viewModel.getAllMonths().first {
                selectedMonth = firstMonth
            }
        }
    }
}

struct PieChartView: View {
    var data: [String: Double]
    var colors: [Color]
    
    private var total: Double {
        data.values.reduce(0, +)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                ForEach(Array(data.keys.enumerated()), id: \.element) { index, key in
                    if let value = data[key], value > 0, index < colors.count {
                        PieSliceView(
                            center: center,
                            radius: radius,
                            startAngle: self.startAngle(for: index),
                            endAngle: self.endAngle(for: index),
                            color: colors[index]
                        )
                    }
                }
                
                // 中心圆形
                Circle()
                    .fill(Color.white)
                    .frame(width: radius, height: radius)
            }
        }
    }
    
    private func startAngle(for index: Int) -> Double {
        let keys = Array(data.keys)
        var sum: Double = 0
        
        for i in 0..<index {
            if i < keys.count, let value = data[keys[i]] {
                sum += value
            }
        }
        
        return sum / total * 360
    }
    
    private func endAngle(for index: Int) -> Double {
        let keys = Array(data.keys)
        if index < keys.count, let value = data[keys[index]] {
            return startAngle(for: index) + (value / total * 360)
        }
        return startAngle(for: index)
    }
}

struct PieSliceView: View {
    var center: CGPoint
    var radius: CGFloat
    var startAngle: Double
    var endAngle: Double
    var color: Color
    
    var body: some View {
        Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(degrees: startAngle),
                endAngle: Angle(degrees: endAngle),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(color)
    }
}

#Preview {
    // 创建一个模拟的 TransactionViewModel 实例用于预览
    let context = PersistenceController.preview.container.viewContext
    let viewModel = TransactionViewModel(context: context)
    // 可以选择性地添加一些模拟数据到 viewModel.transactions 以便预览
    // viewModel.addTransaction(Transaction(amount: 100, date: Date(), category: "餐饮美食", description: "午餐", type: .expense, paymentMethod: "微信"))
    // viewModel.addTransaction(Transaction(amount: 5000, date: Date(), category: "主业收入", description: "工资", type: .income, paymentMethod: "招商银行卡"))
    
    ChartView(viewModel: viewModel)
        .environment(\.managedObjectContext, context)
}
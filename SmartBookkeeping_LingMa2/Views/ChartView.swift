//
//  ChartView.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct ChartView: View {
    init(data: [String : Double]) {
        self.data = data
    }
    var data: [String: Double]
    
    private var total: Double {
        data.values.reduce(0, +)
    }
    
    private var colors: [Color] = [.blue, .green, .orange, .red]
    
    var body: some View {
        VStack {
            ZStack {
                // 饼图
                PieChartView(data: data, colors: colors)
                    .frame(width: 150, height: 150)
                    .padding()
            }
            
            // 图例
            HStack(spacing: 20) {
                ForEach(Array(data.keys.enumerated()), id: \.element) { index, key in
                    if index < colors.count {
                        HStack {
                            Circle()
                                .fill(colors[index])
                                .frame(width: 10, height: 10)
                            Text(key)
                                .font(.caption)
                        }
                    }
                }
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
    ChartView(data: [
        "收入": 3000,
        "支出": 2000,
        "转账": 1000,
        // "投资": 500
    ])
    .frame(height: 200)
    .padding()
}
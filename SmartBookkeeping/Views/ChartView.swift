//
//  ChartView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

// 时间筛选类型枚举
enum TimeFilterType: String, CaseIterable {
    case day = "按天"
    case week = "按周"
    case month = "按月"
    case quarter = "按季度"
    case year = "按年"
    case custom = "自定义"
}

struct ChartView: View {
    @ObservedObject var viewModel: TransactionViewModel

    // 显式声明 internal init，尽管这是默认的
    internal init(viewModel: TransactionViewModel) {
        self.viewModel = viewModel
    }
    
    @State private var selectedTimeFilterType: TimeFilterType = .month
    @State private var selectedMonth: String = "全部月份"
    @State private var selectedDay: Date = Date()
    @State private var selectedWeek: Date = Date()
    @State private var selectedQuarter: String = "全部季度"
    @State private var selectedYear: String = "全部年份"
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showingCustomDatePicker = false

    // data 现在是一个计算属性，依赖于选择的时间筛选
    private var chartData: [String: Double] {
        switch selectedTimeFilterType {
        case .day:
            return viewModel.getTransactionTypeDistribution(forDay: selectedDay)
        case .week:
            return viewModel.getTransactionTypeDistribution(forWeek: selectedWeek)
        case .month:
            return viewModel.getTransactionTypeDistribution(forMonth: selectedMonth)
        case .quarter:
            return viewModel.getTransactionTypeDistribution(forQuarter: selectedQuarter)
        case .year:
            return viewModel.getTransactionTypeDistribution(forYear: selectedYear)
        case .custom:
            return viewModel.getTransactionTypeDistribution(from: customStartDate, to: customEndDate)
        }
    }
    
    private var total: Double {
        chartData.values.reduce(0, +)
    }
    
    // 计算当前选择时间范围的收入、支出和结余
    private var periodIncome: Double {
        switch selectedTimeFilterType {
        case .day:
            return viewModel.getDayIncome(forDay: selectedDay)
        case .week:
            return viewModel.getWeekIncome(forWeek: selectedWeek)
        case .month:
            return viewModel.getMonthlyIncome(forMonth: selectedMonth)
        case .quarter:
            return viewModel.getQuarterIncome(forQuarter: selectedQuarter)
        case .year:
            return viewModel.getYearIncome(forYear: selectedYear)
        case .custom:
            return viewModel.getCustomRangeIncome(from: customStartDate, to: customEndDate)
        }
    }
    
    private var periodExpense: Double {
        switch selectedTimeFilterType {
        case .day:
            return viewModel.getDayExpense(forDay: selectedDay)
        case .week:
            return viewModel.getWeekExpense(forWeek: selectedWeek)
        case .month:
            return viewModel.getMonthlyExpense(forMonth: selectedMonth)
        case .quarter:
            return viewModel.getQuarterExpense(forQuarter: selectedQuarter)
        case .year:
            return viewModel.getYearExpense(forYear: selectedYear)
        case .custom:
            return viewModel.getCustomRangeExpense(from: customStartDate, to: customEndDate)
        }
    }
    
    private var periodBalance: Double {
        periodIncome - periodExpense
    }
    
    private var colors: [Color] = [.blue, .green, .orange, .red] // 可以根据需要扩展颜色
    
    // 时间筛选视图
    @ViewBuilder
    private var timeFilterView: some View {
        switch selectedTimeFilterType {
        case .day:
            VStack {
                Text("选择日期")
                    .font(.caption)
                    .foregroundColor(.secondary)
                DatePicker("", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
            }
            .padding(.horizontal)
        case .week:
            VStack {
                Text("选择周")
                    .font(.caption)
                    .foregroundColor(.secondary)
                DatePicker("", selection: $selectedWeek, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
            }
            .padding(.horizontal)
        case .month:
            Picker("选择月份", selection: $selectedMonth) {
                ForEach(viewModel.getAllMonths(), id: \.self) { month in
                    Text(month)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)
        case .quarter:
            Picker("选择季度", selection: $selectedQuarter) {
                ForEach(viewModel.getAllQuarters(), id: \.self) { quarter in
                    Text(quarter)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)
        case .year:
            Picker("选择年份", selection: $selectedYear) {
                ForEach(viewModel.getAllYears(), id: \.self) { year in
                    Text(year)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)
        case .custom:
            VStack(spacing: 10) {
                Button(action: {
                    showingCustomDatePicker = true
                }) {
                    HStack {
                        Text("自定义时间范围")
                        Spacer()
                        Text("\(formatDate(customStartDate)) - \(formatDate(customEndDate))")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .sheet(isPresented: $showingCustomDatePicker) {
                CustomDateRangePickerView(
                    startDate: $customStartDate,
                    endDate: $customEndDate,
                    isPresented: $showingCustomDatePicker
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack {
            // 时间筛选类型选择器
            Picker("筛选类型", selection: $selectedTimeFilterType) {
                ForEach(TimeFilterType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // 具体时间选择器
            timeFilterView
            
            // 结余统计信息
            VStack(spacing: 12) {
                // 结余信息
                HStack {
                    Spacer()
                    VStack {
                        Text("结余")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", periodBalance))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(periodBalance >= 0 ? .primary : .red)
                    }
                    Spacer()
                }
                
                // 收入支出详情
                HStack {
                    VStack(alignment: .leading) {
                        Text("收入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", periodIncome))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", periodExpense))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)

            Spacer() 
            
            if total > 0 { // 仅当有数据时显示饼图和图例
                ScrollView {
                    VStack(spacing: 20) {
                        // 收支饼图部分
                        VStack {
                            Text("收支分布")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            ZStack {
                                PieChartView(data: chartData, colors: colors)
                                    .frame(width: 200, height: 200) 
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
                        }
                        
                        // 分类统计选择和条形图部分
                        CategoryStatisticsView(viewModel: viewModel, selectedMonth: selectedMonth)
                    }
                }
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

// 分类统计视图（包含支出和收入选择）
struct CategoryStatisticsView: View {
    @ObservedObject var viewModel: TransactionViewModel
    let selectedMonth: String
    @State private var selectedType: StatisticsType = .expense
    
    enum StatisticsType: String, CaseIterable {
        case expense = "支出"
        case income = "收入"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 选择按钮
            HStack(spacing: 12) {
                ForEach(StatisticsType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                    }) {
                        Text("分类\(type.rawValue)统计")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedType == type ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedType == type ? Color.blue : Color.gray.opacity(0.2))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // 对应的条形图
            if selectedType == .expense {
                CategoryExpenseBarChartView(viewModel: viewModel, selectedMonth: selectedMonth)
            } else {
                CategoryIncomeBarChartView(viewModel: viewModel, selectedMonth: selectedMonth)
            }
        }
    }
}

// 分类支出条形图视图
struct CategoryExpenseBarChartView: View {
    @ObservedObject var viewModel: TransactionViewModel
    let selectedMonth: String
    
    private var categoryData: [String: Double] {
        viewModel.getCategoryExpenseDistribution(forMonth: selectedMonth)
    }
    
    private var maxAmount: Double {
        categoryData.values.max() ?? 0
    }
    
    private var sortedCategories: [(String, Double)] {
        categoryData.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if !categoryData.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedCategories, id: \.0) { category, amount in
                        CategoryBarView(
                            categoryName: category,
                            amount: amount,
                            maxAmount: maxAmount,
                            percentage: maxAmount > 0 ? amount / maxAmount : 0,
                            color: .red
                        )
                    }
                }
                .padding(.horizontal)
            } else {
                Text("当前月份无支出数据")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

// 分类收入条形图视图
struct CategoryIncomeBarChartView: View {
    @ObservedObject var viewModel: TransactionViewModel
    let selectedMonth: String
    
    private var categoryData: [String: Double] {
        viewModel.getCategoryIncomeDistribution(forMonth: selectedMonth)
    }
    
    private var maxAmount: Double {
        categoryData.values.max() ?? 0
    }
    
    private var sortedCategories: [(String, Double)] {
        categoryData.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if !categoryData.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedCategories, id: \.0) { category, amount in
                        CategoryBarView(
                            categoryName: category,
                            amount: amount,
                            maxAmount: maxAmount,
                            percentage: maxAmount > 0 ? amount / maxAmount : 0,
                            color: .green
                        )
                    }
                }
                .padding(.horizontal)
            } else {
                Text("当前月份无收入数据")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

// 单个分类条形图项
struct CategoryBarView: View {
    let categoryName: String
    let amount: Double
    let maxAmount: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(categoryName)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.2f", amount))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    // 数据条
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.8), color]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.8), value: percentage)
                }
            }
            .frame(height: 8)
        }
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
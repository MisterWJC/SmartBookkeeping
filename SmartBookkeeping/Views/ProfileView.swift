//
//  ProfileView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/7/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    // @State private var showingShareSheet = false // Removed
    // @State private var documentURL: URL? // This will now drive the sheet presentation - Replaced by shareableUrl
    @State private var shareableUrl: ShareableURL? // Wrapper to make URL Identifiable
    @State private var showingCategoryManagement = false
    @State private var showingAPIConfiguration = false
    @State private var isAPIConfigured = false
    
    private let configManager = ConfigurationManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button(action: {
                    showingCategoryManagement = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("交易分类与账户管理")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    showingAPIConfiguration = true
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "key")
                            Text("API配置")
                        }
                        
                        HStack(spacing: 4) {
                            if isAPIConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("已配置")
                                    .font(.caption)
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("未配置")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    exportTransactions()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出交易记录")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("我的")
            .sheet(item: $shareableUrl) { identifiableUrl in
                ShareSheet(activityItems: [identifiableUrl.url])
            }
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView()
            }
            .sheet(isPresented: $showingAPIConfiguration) {
                APIConfigurationView()
                    .onDisappear {
                        updateAPIConfigurationStatus()
                    }
            }
            .onAppear {
                updateAPIConfigurationStatus()
            }
        }
    }

    func exportTransactions() {
        // 1. Fetch transactions
        let transactions = transactionViewModel.transactions // Assuming this fetches all

        // 2. Convert to CSV string
        let csvString = convertToCSV(transactions: transactions)

        // 3. Save to a temporary file
        let fileName = "transactions_export.csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            self.shareableUrl = ShareableURL(url: fileURL) // Setting this will trigger the .sheet(item: $shareableUrl)
            // self.documentURL = fileURL // Removed
            // self.showingShareSheet = true // Removed
            print("CSV file saved to: \(fileURL)")
        } catch {
            print("Failed to save CSV file: \(error.localizedDescription)")
            // Handle error (e.g., show an alert to the user)
        }
    }

    func convertToCSV(transactions: [Transaction]) -> String {
        var csvText = "交易时间,交易分类,商品说明,罐头分类,收/支,金额,付款方式,备注\n"

        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"

        for transaction in transactions {
            let dateTimeStr = dateTimeFormatter.string(from: transaction.date)
            let transactionCategoryStr = escapeCSVField(transaction.category) // 交易分类
            let productDescriptionStr = escapeCSVField(transaction.description) // 商品说明
            let cannedCategoryStr = "" // 罐头分类 - Placeholder, as it's not in the model
            let incomeExpenseStr = transaction.type == .expense ? "支" : "收"
            let amountStr = String(format: "%.2f", transaction.amount)
            let paymentMethodStr = escapeCSVField(transaction.paymentMethod)
            let noteStr = escapeCSVField(transaction.note)
            
            let newLine = "\(dateTimeStr)," + // 交易时间
                          "\(transactionCategoryStr)," + // 交易分类
                          "\(productDescriptionStr)," + // 商品说明
                          "\(cannedCategoryStr)," + // 罐头分类
                          "\(incomeExpenseStr)," + // 收/支
                          "\(amountStr)," + // 金额
                          "\(paymentMethodStr)," + // 付款方式
                          "\(noteStr)\n" // 备注
            csvText.append(newLine)
        }
        return csvText
    }

    // 辅助函数：转义CSV字段中的特殊字符
    func escapeCSVField(_ field: String) -> String {
        // 检查是否包含逗号、双引号或换行符
        let charactersToEscape = CharacterSet(charactersIn: ",\"\n\r")
        if field.rangeOfCharacter(from: charactersToEscape) != nil {
            // 如果包含特殊字符，则用双引号包围，并将字段内的双引号替换为两个双引号
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field // 如果没有特殊字符，直接返回原字段
    }
    
    private func updateAPIConfigurationStatus() {
        isAPIConfigured = configManager.isAPIConfigured
    }
}

// Wrapper struct to make URL Identifiable for .sheet(item:)
struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Helper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


#Preview {
    let previewContext = PersistenceController.preview.container.viewContext
    let viewModel = TransactionViewModel(context: previewContext)
    
    // Add sample data to the viewModel
    let calendar = Calendar.current
    let today = Date()
    viewModel.addTransaction(Transaction(amount: 100, date: today, category: "餐饮", description: "午餐", type: .expense, paymentMethod: "支付宝", note: "和同事一起"))
    viewModel.addTransaction(Transaction(amount: 2000, date: calendar.date(byAdding: .day, value: -1, to: today)!, category: "工资", description: "月薪", type: .income, paymentMethod: "银行卡", note: ""))
    
    return ProfileView().environmentObject(viewModel)
}

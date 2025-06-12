import SwiftUI
import UniformTypeIdentifiers

// 导入账单文件UI

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransactionViewModel
    @State private var showingFilePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var importedCount = 0
    
    private let csvService = CSVImportService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 说明文本
                VStack(alignment: .leading, spacing: 10) {
                    Text("CSV 文件格式说明")
                        .font(.headline)
                    Text("请确保 CSV 文件包含以下列：")
                        .font(.subheadline)
                    Text("• 金额（必需）")
                    Text("• 日期（可选，格式：yyyy-MM-dd HH:mm:ss）")
                    Text("• 分类（可选）")
                    Text("• 描述（可选）")
                    Text("• 类型（可选，收入/支出）")
                    Text("• 支付方式（可选）")
                    Text("• 备注（可选）")
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                // 示例数据
                VStack(alignment: .leading, spacing: 10) {
                    Text("示例数据：")
                        .font(.headline)
                    Text("金额,日期,分类,描述,类型,支付方式,备注")
                    Text("100.50,2024-03-20 14:30:00,餐饮美食,午餐,支出,微信,公司午餐")
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                // 导入按钮
                Button(action: {
                    showingFilePicker = true
                }) {
                    Text("选择 CSV 文件")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("导入 CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                guard let file = files.first else { return }
                
                // 读取文件内容
                do {
                    let data = try Data(contentsOf: file)
                    guard let csvString = String(data: data, encoding: .utf8) else {
                        throw CSVImportService.CSVImportError.encodingFailed
                    }
                    
                    print("DEBUG: CSV String read from file:\n\(csvString)")

                    // 解析 CSV
                    let transactions = try csvService.parseCSV(csvString)
                    
                    // 保存交易记录
                    for transaction in transactions {
                        let newTransaction = Transaction(
                            amount: transaction.amount,
                            date: transaction.date,
                            category: transaction.category,
                            description: transaction.description,
                            type: transaction.type,
                            paymentMethod: transaction.paymentMethod,
                            note: transaction.note
                        )
                        viewModel.addTransaction(newTransaction)
                    }
                    
                    importedCount = transactions.count
                    showingSuccess = true
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .alert("导入错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("导入成功", isPresented: $showingSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("成功导入 \(importedCount) 条交易记录")
        }
    }
} 
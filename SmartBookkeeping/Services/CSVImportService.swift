import Foundation

struct CSVTransaction {
    let amount: Double
    let date: Date
    let category: String
    let description: String
    let type: Transaction.TransactionType
    let paymentMethod: String
    let note: String
}

class CSVImportService {
    enum CSVImportError: Error, LocalizedError {
        case invalidFormat
        case missingAmount
        case invalidAmount(String)
        case invalidDate
        case invalidType
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "CSV文件格式不正确，请确保文件包含表头且有数据行。"
            case .missingAmount:
                return "CSV文件中缺少必需的金额列。"
            case .invalidAmount(let amountString):
                return "金额格式不正确: \(amountString)。请确保金额是纯数字。"
            case .invalidDate:
                return "日期格式不正确。请确保日期格式为 yyyy/MM/dd HH:mm:ss。"
            case .invalidType:
                return "收/支类型不正确。请使用'收入'或'支出'。"
            case .encodingFailed:
                return "CSV文件编码错误。请确保文件是UTF-8编码。"
            }
        }
    }
    
    func parseCSV(_ csvString: String) throws -> [CSVTransaction] {
        var transactions: [CSVTransaction] = []
        
        // Split by newlines and filter out empty lines to handle blank rows or trailing newlines
        let rows = csvString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // 检查是否有数据（至少需要一个表头行和一个数据行）
        guard rows.count > 1 else {
            throw CSVImportError.invalidFormat // This means no data rows or only header
        }
        
        // 获取表头
        let headers = rows[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 检查必要的列是否存在
        guard let amountIndex = headers.firstIndex(of: "金额") else {
            throw CSVImportError.missingAmount
        }
        
        // 创建列索引映射
        let dateIndex = headers.firstIndex(of: "交易时间")
        let categoryIndex = headers.firstIndex(of: "交易分类")
        let descriptionIndex = headers.firstIndex(of: "商品说明")
        let typeIndex = headers.firstIndex(of: "收/支")
        let paymentMethodIndex = headers.firstIndex(of: "付款方式")
        let noteIndex = headers.firstIndex(of: "备注")
        
        // 日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        
        // 处理每一行数据
        for row in rows.dropFirst() {
            let columns = row.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            // 检查金额
            guard let amountString = columns[safe: amountIndex] else {
                throw CSVImportError.invalidAmount("") // If amountString is entirely missing, pass an empty string
            }
            
            guard let amount = Double(amountString) else {
                throw CSVImportError.invalidAmount(amountString)
            }
            
            // 解析日期
            let date: Date
            if let dateIndex = dateIndex,
               let dateString = columns[safe: dateIndex] {
                if let parsedDate = dateFormatter.date(from: dateString) {
                    date = parsedDate
                } else {
                    date = Date() // 如果日期无效，使用当前日期
                }
            } else {
                date = Date()
            }
            
            // 解析类型
            let type: Transaction.TransactionType
            if let typeIndex = typeIndex,
               let typeString = columns[safe: typeIndex] {
                type = typeString.lowercased() == "收入" ? .income : .expense
            } else {
                type = amount >= 0 ? .income : .expense
            }
            
            // 创建交易记录
            let transaction = CSVTransaction(
                amount: abs(amount),
                date: date,
                category: categoryIndex.flatMap { columns[safe: $0] } ?? "未分类",
                description: descriptionIndex.flatMap { columns[safe: $0] } ?? "",
                type: type,
                paymentMethod: paymentMethodIndex.flatMap { columns[safe: $0] } ?? "未知",
                note: noteIndex.flatMap { columns[safe: $0] } ?? ""
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
}

// 扩展 Array 以安全访问元素
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 
import Foundation

struct TransactionData: Equatable {
    let amount: Double
    let category: String
    let date: Date
    let note: String
    let type: Transaction.TransactionType
    
    static func == (lhs: TransactionData, rhs: TransactionData) -> Bool {
        return lhs.amount == rhs.amount &&
               lhs.category == rhs.category &&
               lhs.date == rhs.date &&
               lhs.note == rhs.note &&
               lhs.type == rhs.type
    }
}

enum TransactionType {
    case expense
    case income
} 
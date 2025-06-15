import Foundation

public struct AIResponse: Codable {
    public let amount: Double?
    public let transaction_time: String?
    public let item_description: String?
    public let category: String?
    public let transaction_type: String?
    public let payment_method: String?
    public let notes: String?
    
    public init(amount: Double? = nil,
                transaction_time: String? = nil,
                item_description: String? = nil,
                category: String? = nil,
                transaction_type: String? = nil,
                payment_method: String? = nil,
                notes: String? = nil) {
        self.amount = amount
        self.transaction_time = transaction_time
        self.item_description = item_description
        self.category = category
        self.transaction_type = transaction_type
        self.payment_method = payment_method
        self.notes = notes
    }
}
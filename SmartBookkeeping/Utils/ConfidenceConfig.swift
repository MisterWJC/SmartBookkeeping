struct ConfidenceConfig {
    static let lowConfidenceThreshold: Double = 0.7
    static let mediumConfidenceThreshold: Double = 0.8
    
    // 不同字段的默认置信度
    struct Defaults {
        static let amount: Double = 0.9
        static let category: Double = 0.6
        static let account: Double = 0.6  // 你的修改
        static let description: Double = 0.5
        static let date: Double = 0.9
        static let notes: Double = 0.3
    }
}
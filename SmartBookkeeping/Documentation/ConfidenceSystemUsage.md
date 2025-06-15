# 置信度系统使用指南

本文档介绍如何在 SmartBookkeeping 应用中使用新的置信度系统，包括置信度学习、缓存和用户反馈机制。

## 系统架构

### 核心组件

1. **ConfidenceConfig** - 置信度配置管理
2. **ConfidenceLearningService** - 置信度学习服务
3. **ConfidenceCacheService** - 置信度缓存服务
4. **AppInitializer** - 应用初始化器

### 数据流

```
AI识别结果 → 置信度计算 → 缓存检查 → 学习服务 → 最终置信度
     ↓
用户确认/修正 → 反馈记录 → 学习更新 → 缓存清理
```

## 使用方法

### 1. 获取置信度

```swift
// 在 BillProcessingService 中
private func validateConfidenceScores(_ response: AIResponse) -> ConfidenceScores {
    let learningService = ConfidenceLearningService.shared
    let cacheService = ConfidenceCacheService.shared
    
    var scores = ConfidenceScores()
    
    // 使用缓存和学习服务计算置信度
    scores.amount = cacheService.getOrCalculateConfidence(
        for: "amount",
        value: "\(response.amount ?? 0.0)"
    ) {
        learningService.getSuggestedConfidence(
            for: "amount",
            value: response.amount != nil ? "\(response.amount!)" : nil
        )
    }
    
    return scores
}
```

### 2. 记录用户反馈

```swift
// 当用户确认或修正AI识别结果时
func handleUserConfirmation(originalResponse: AIResponse, finalTransaction: Transaction) {
    BillProcessingService.shared.recordUserFeedback(
        originalResponse: originalResponse,
        correctedTransaction: finalTransaction
    )
}
```

### 3. 在UI中显示置信度

```swift
// 在 ClickableTagRow 中
struct ClickableTagRow: View {
    let confidence: Double
    private let lowConfidenceThreshold = ConfidenceConfig.lowConfidenceThreshold
    
    private var isLowConfidence: Bool {
        confidence < lowConfidenceThreshold
    }
    
    var body: some View {
        HStack {
            // 显示置信度指示器
            if isLowConfidence {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
            }
            
            Text(title)
            Spacer()
            
            Text(value)
                .foregroundColor(isLowConfidence ? .orange : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isLowConfidence ? Color.orange : Color.clear, 
                               style: StrokeStyle(lineWidth: 1, dash: [2]))
                )
        }
    }
}
```

### 4. 配置置信度阈值

```swift
// 在 ConfidenceConfig.swift 中
struct ConfidenceConfig {
    static let lowConfidenceThreshold: Double = 0.7
    static let mediumConfidenceThreshold: Double = 0.8
    
    struct Defaults {
        static let amount: Double = 0.9
        static let category: Double = 0.6
        static let account: Double = 0.6
        static let description: Double = 0.5
        static let date: Double = 0.9
        static let notes: Double = 0.3
    }
}
```

## 最佳实践

### 1. 置信度阈值设置

- **高置信度 (≥0.8)**: 绿色显示，用户通常不需要检查
- **中等置信度 (0.7-0.8)**: 正常显示，建议用户检查
- **低置信度 (<0.7)**: 橙色显示，强烈建议用户确认

### 2. 用户反馈收集

```swift
// 在用户编辑完成后调用
func onUserEditComplete() {
    if let originalResponse = self.originalAIResponse {
        BillProcessingService.shared.recordUserFeedback(
            originalResponse: originalResponse,
            correctedTransaction: self.currentTransaction
        )
    }
}
```

### 3. 缓存管理

```swift
// 获取缓存统计信息
let stats = ConfidenceCacheService.shared.getCacheStatistics()
print("缓存命中率: \(stats.hitRate * 100)%")

// 清理特定字段的缓存
ConfidenceCacheService.shared.clearCache(for: "category")

// 预热缓存
let commonValues = ConfidenceCacheService.getCommonValues()
ConfidenceCacheService.shared.warmupCache(with: commonValues)
```

### 4. 学习服务监控

```swift
// 获取各字段的准确率
let learningService = ConfidenceLearningService.shared
let amountAccuracy = learningService.getAccuracyRate(for: "amount")
let categoryAccuracy = learningService.getAccuracyRate(for: "category")

print("金额识别准确率: \(amountAccuracy * 100)%")
print("类别识别准确率: \(categoryAccuracy * 100)%")
```

## 调试和监控

### 1. 诊断信息导出

```swift
// 导出完整的诊断信息
let diagnosticInfo = AppInitializer.shared.exportDiagnosticInfo()
print("诊断信息: \(diagnosticInfo)")
```

### 2. 初始化状态检查

```swift
// 检查应用初始化状态
let status = AppInitializer.shared.getInitializationStatus()
print(status.description)
```

### 3. 性能监控

```swift
// 监控缓存性能
let cacheStats = ConfidenceCacheService.shared.getCacheStatistics()
if cacheStats.hitRate < 0.5 {
    print("警告: 缓存命中率过低 (\(cacheStats.hitRate * 100)%)")
}
```

## 测试

### 单元测试

运行置信度系统的单元测试：

```bash
# 运行所有置信度相关测试
xcodebuild test -scheme SmartBookkeeping -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SmartBookkeepingTests/ConfidenceTests
```

### 集成测试

```swift
// 测试完整的置信度流程
func testFullConfidenceFlow() {
    // 1. 模拟AI响应
    let aiResponse = AIResponse(amount: 100.0, category: "餐饮")
    
    // 2. 计算置信度
    let scores = BillProcessingService.shared.validateConfidenceScores(aiResponse)
    
    // 3. 模拟用户修正
    let correctedTransaction = Transaction(amount: 105.0, category: "午餐")
    
    // 4. 记录反馈
    BillProcessingService.shared.recordUserFeedback(
        originalResponse: aiResponse,
        correctedTransaction: correctedTransaction
    )
    
    // 5. 验证学习效果
    let newConfidence = ConfidenceLearningService.shared.getSuggestedConfidence(
        for: "amount",
        value: "100.0"
    )
    
    XCTAssertLessThan(newConfidence, scores.amount)
}
```

## 故障排除

### 常见问题

1. **置信度始终为默认值**
   - 检查 AppInitializer 是否正确调用
   - 确认学习服务是否有历史数据

2. **缓存命中率过低**
   - 检查缓存预热是否正确执行
   - 确认常用值列表是否合适

3. **学习效果不明显**
   - 确认用户反馈是否正确记录
   - 检查反馈数据的质量和数量

### 重置数据

```swift
// 重置所有学习和缓存数据
AppInitializer.shared.resetAllData()
```

## 性能考虑

1. **缓存大小**: 默认最大1000条记录
2. **缓存过期**: 1小时自动过期
3. **清理频率**: 每5分钟清理一次过期条目
4. **学习数据**: 最多保留1000条用户反馈记录

## 未来扩展

1. **机器学习模型**: 可以集成更复杂的ML模型
2. **云端同步**: 将学习数据同步到云端
3. **个性化推荐**: 基于用户习惯提供个性化建议
4. **A/B测试**: 测试不同置信度策略的效果
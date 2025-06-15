//
//  ConfidenceTests.swift
//  SmartBookkeepingTests
//
//  Created by Assistant on 2025/1/27.
//

import XCTest
@testable import SmartBookkeeping

class ConfidenceTests: XCTestCase {
    
    var learningService: ConfidenceLearningService!
    
    override func setUp() {
        super.setUp()
        learningService = ConfidenceLearningService.shared
        // 清除测试前的数据
        learningService.clearFeedbackHistory()
    }
    
    override func tearDown() {
        // 清除测试后的数据
        learningService.clearFeedbackHistory()
        super.tearDown()
    }
    
    // MARK: - ConfidenceConfig 测试
    
    func testConfidenceConfigDefaults() {
        XCTAssertEqual(ConfidenceConfig.Defaults.amount, 0.9)
        XCTAssertEqual(ConfidenceConfig.Defaults.category, 0.6)
        XCTAssertEqual(ConfidenceConfig.Defaults.account, 0.6)
        XCTAssertEqual(ConfidenceConfig.Defaults.description, 0.5)
        XCTAssertEqual(ConfidenceConfig.Defaults.date, 0.9)
        XCTAssertEqual(ConfidenceConfig.Defaults.notes, 0.3)
    }
    
    func testConfidenceThresholds() {
        XCTAssertEqual(ConfidenceConfig.lowConfidenceThreshold, 0.7)
        XCTAssertEqual(ConfidenceConfig.mediumConfidenceThreshold, 0.8)
    }
    
    // MARK: - ConfidenceLearningService 测试
    
    func testRecordUserFeedback() {
        // 记录正确的反馈
        learningService.recordUserFeedback(
            field: "amount",
            originalValue: "100.0",
            correctedValue: nil,
            wasCorrect: true,
            originalConfidence: 0.9
        )
        
        // 记录错误的反馈
        learningService.recordUserFeedback(
            field: "amount",
            originalValue: "50.0",
            correctedValue: "55.0",
            wasCorrect: false,
            originalConfidence: 0.8
        )
        
        // 验证准确率计算
        let accuracyRate = learningService.getAccuracyRate(for: "amount")
        XCTAssertEqual(accuracyRate, 0.5, accuracy: 0.01) // 1正确/2总数 = 0.5
    }
    
    func testSuggestedConfidenceWithoutHistory() {
        // 没有历史数据时，应该返回默认值
        let confidence = learningService.getSuggestedConfidence(for: "amount", value: "100.0")
        XCTAssertEqual(confidence, ConfidenceConfig.Defaults.amount, accuracy: 0.01)
    }
    
    func testSuggestedConfidenceWithHistory() {
        // 添加一些历史数据
        for i in 0..<10 {
            learningService.recordUserFeedback(
                field: "category",
                originalValue: "餐饮",
                correctedValue: nil,
                wasCorrect: i < 8, // 80% 准确率
                originalConfidence: 0.6
            )
        }
        
        let confidence = learningService.getSuggestedConfidence(for: "category", value: "餐饮")
        // 应该根据80%的准确率调整置信度
        let expectedConfidence = ConfidenceConfig.Defaults.category * (0.5 + 0.8 * 0.5)
        XCTAssertEqual(confidence, expectedConfidence, accuracy: 0.01)
    }
    
    func testSuggestedConfidenceForEmptyValue() {
        // 空值应该返回很低的置信度
        let confidence = learningService.getSuggestedConfidence(for: "account", value: "")
        XCTAssertLessThan(confidence, 0.3)
    }
    
    func testSuggestedConfidenceForDefaultValue() {
        // 默认值应该返回较低的置信度
        let confidence = learningService.getSuggestedConfidence(for: "category", value: "未分类")
        XCTAssertLessThan(confidence, 0.4)
    }
    
    func testAccuracyRateCalculation() {
        // 测试准确率计算
        learningService.recordUserFeedback(
            field: "description",
            originalValue: "午餐",
            correctedValue: nil,
            wasCorrect: true,
            originalConfidence: 0.7
        )
        
        learningService.recordUserFeedback(
            field: "description",
            originalValue: "晚餐",
            correctedValue: "晚饭",
            wasCorrect: false,
            originalConfidence: 0.6
        )
        
        learningService.recordUserFeedback(
            field: "description",
            originalValue: "早餐",
            correctedValue: nil,
            wasCorrect: true,
            originalConfidence: 0.8
        )
        
        let accuracyRate = learningService.getAccuracyRate(for: "description")
        XCTAssertEqual(accuracyRate, 2.0/3.0, accuracy: 0.01) // 2正确/3总数
    }
    
    func testClearFeedbackHistory() {
        // 添加一些数据
        learningService.recordUserFeedback(
            field: "amount",
            originalValue: "100.0",
            correctedValue: nil,
            wasCorrect: true,
            originalConfidence: 0.9
        )
        
        // 验证数据存在
        XCTAssertGreaterThan(learningService.getAccuracyRate(for: "amount"), 0)
        
        // 清除数据
        learningService.clearFeedbackHistory()
        
        // 验证数据已清除
        XCTAssertEqual(learningService.getAccuracyRate(for: "amount"), 0)
    }
    
    // MARK: - ConfidenceScores 测试
    
    func testConfidenceScoresInitialization() {
        let scores = ConfidenceScores()
        
        // 验证默认值
        XCTAssertEqual(scores.amount, ConfidenceConfig.Defaults.amount)
        XCTAssertEqual(scores.category, ConfidenceConfig.Defaults.category)
        XCTAssertEqual(scores.account, ConfidenceConfig.Defaults.account)
        XCTAssertEqual(scores.description, ConfidenceConfig.Defaults.description)
        XCTAssertEqual(scores.date, ConfidenceConfig.Defaults.date)
        XCTAssertEqual(scores.notes, ConfidenceConfig.Defaults.notes)
    }
    
    // MARK: - 性能测试
    
    func testConfidenceLearningPerformance() {
        measure {
            // 测试大量反馈记录的性能
            for i in 0..<100 {
                learningService.recordUserFeedback(
                    field: "amount",
                    originalValue: "\(i * 10).0",
                    correctedValue: nil,
                    wasCorrect: i % 2 == 0,
                    originalConfidence: 0.8
                )
            }
            
            // 测试置信度计算性能
            for _ in 0..<50 {
                _ = learningService.getSuggestedConfidence(for: "amount", value: "100.0")
            }
        }
    }
    
    // MARK: - 边界条件测试
    
    func testConfidenceBoundaries() {
        // 测试置信度边界值
        let minConfidence = learningService.getSuggestedConfidence(for: "notes", value: "")
        XCTAssertGreaterThanOrEqual(minConfidence, 0.1)
        
        // 添加完美准确率的历史数据
        for _ in 0..<10 {
            learningService.recordUserFeedback(
                field: "date",
                originalValue: "2025-01-27",
                correctedValue: nil,
                wasCorrect: true,
                originalConfidence: 0.9
            )
        }
        
        let maxConfidence = learningService.getSuggestedConfidence(for: "date", value: "2025-01-27")
        XCTAssertLessThanOrEqual(maxConfidence, 0.95)
    }
}
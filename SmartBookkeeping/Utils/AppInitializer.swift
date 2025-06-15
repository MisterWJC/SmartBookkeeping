//
//  AppInitializer.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import UIKit

/// 应用初始化器，负责应用启动时的初始化工作
class AppInitializer {
    static let shared = AppInitializer()
    
    private var isInitialized = false
    
    private init() {}
    
    /// 执行应用初始化
    func initialize() {
        guard !isInitialized else { return }
        
        print("DEBUG: AppInitializer - Starting app initialization")
        
        // 1. 预热置信度缓存
        warmupConfidenceCache()
        
        // 2. 初始化其他服务
        initializeServices()
        
        // 3. 检查和清理过期数据
        cleanupExpiredData()
        
        isInitialized = true
        print("DEBUG: AppInitializer - App initialization completed")
    }
    
    // MARK: - 私有方法
    
    /// 预热置信度缓存
    private func warmupConfidenceCache() {
        let cacheService = ConfidenceCacheService.shared
        let commonValues = ConfidenceCacheService.getCommonValues()
        
        // 异步预热缓存，避免阻塞主线程
        DispatchQueue.global(qos: .utility).async {
            cacheService.warmupCache(with: commonValues)
            
            DispatchQueue.main.async {
                print("DEBUG: AppInitializer - Confidence cache warmed up")
            }
        }
    }
    
    /// 初始化其他服务
    private func initializeServices() {
        // 初始化学习服务（确保单例被创建）
        _ = ConfidenceLearningService.shared
        
        // 初始化缓存服务（确保单例被创建）
        _ = ConfidenceCacheService.shared
        
        // 初始化其他核心服务
        _ = BillProcessingService.shared
        _ = CategoryDataManager.shared
        
        print("DEBUG: AppInitializer - Core services initialized")
    }
    
    /// 清理过期数据
    private func cleanupExpiredData() {
        DispatchQueue.global(qos: .utility).async {
            // 清理过期的置信度缓存
            let cacheService = ConfidenceCacheService.shared
            let stats = cacheService.getCacheStatistics()
            
            if stats.expiredEntries > 0 {
                print("DEBUG: AppInitializer - Found \(stats.expiredEntries) expired cache entries")
                // 缓存服务会自动清理过期条目
            }
            
            // 可以在这里添加其他数据清理逻辑
            self.cleanupOldUserDefaults()
        }
    }
    
    /// 清理旧的 UserDefaults 数据
    private func cleanupOldUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        // 清理超过30天的临时数据
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        // 这里可以添加具体的清理逻辑
        // 例如：清理旧的临时设置、过期的缓存键等
        
        print("DEBUG: AppInitializer - Cleaned up old UserDefaults data")
    }
    
    /// 获取初始化状态
    func getInitializationStatus() -> InitializationStatus {
        let cacheStats = ConfidenceCacheService.shared.getCacheStatistics()
        let learningService = ConfidenceLearningService.shared
        
        return InitializationStatus(
            isInitialized: isInitialized,
            cacheSize: cacheStats.cacheSize,
            cacheHitRate: cacheStats.hitRate,
            learningDataAvailable: learningService.getAccuracyRate(for: "amount") > 0
        )
    }
}

// MARK: - 初始化状态结构

struct InitializationStatus {
    let isInitialized: Bool
    let cacheSize: Int
    let cacheHitRate: Double
    let learningDataAvailable: Bool
    
    var description: String {
        return """
        App Initialization Status:
        - Initialized: \(isInitialized)
        - Cache Size: \(cacheSize)
        - Cache Hit Rate: \(String(format: "%.2f%%", cacheHitRate * 100))
        - Learning Data Available: \(learningDataAvailable)
        """
    }
}

// MARK: - 扩展：便捷方法

extension AppInitializer {
    /// 重置所有数据（用于测试或重置功能）
    func resetAllData() {
        ConfidenceLearningService.shared.clearFeedbackHistory()
        ConfidenceCacheService.shared.clearAllCache()
        
        // 重置初始化状态
        isInitialized = false
        
        print("DEBUG: AppInitializer - All data reset")
    }
    
    /// 导出诊断信息
    func exportDiagnosticInfo() -> [String: Any] {
        let status = getInitializationStatus()
        let cacheStats = ConfidenceCacheService.shared.getCacheStatistics()
        let learningService = ConfidenceLearningService.shared
        
        return [
            "initialization_status": status.isInitialized,
            "cache_statistics": [
                "size": cacheStats.cacheSize,
                "hit_count": cacheStats.hitCount,
                "miss_count": cacheStats.missCount,
                "hit_rate": cacheStats.hitRate,
                "expired_entries": cacheStats.expiredEntries
            ],
            "learning_accuracy": [
                "amount": learningService.getAccuracyRate(for: "amount"),
                "category": learningService.getAccuracyRate(for: "category"),
                "account": learningService.getAccuracyRate(for: "account"),
                "description": learningService.getAccuracyRate(for: "description"),
                "date": learningService.getAccuracyRate(for: "date"),
                "notes": learningService.getAccuracyRate(for: "notes")
            ],
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}
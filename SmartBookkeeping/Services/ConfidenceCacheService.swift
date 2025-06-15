//
//  ConfidenceCacheService.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation

/// 置信度缓存服务，用于缓存置信度计算结果以提高性能
class ConfidenceCacheService {
    static let shared = ConfidenceCacheService()
    
    // 缓存键结构
    private struct CacheKey: Hashable {
        let field: String
        let value: String
        let contextHash: Int // 用于区分不同上下文
        
        init(field: String, value: String, context: [String: Any] = [:]) {
            self.field = field
            self.value = value
            self.contextHash = context.description.hashValue
        }
    }
    
    // 缓存条目结构
    private struct CacheEntry {
        let confidence: Double
        let timestamp: Date
        let hitCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ConfidenceCacheService.cacheExpirationTime
        }
    }
    
    // 缓存配置
    private static let maxCacheSize = 1000
    private static let cacheExpirationTime: TimeInterval = 3600 // 1小时
    private static let cleanupInterval: TimeInterval = 300 // 5分钟清理一次
    
    // 缓存存储
    private var cache: [CacheKey: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "confidence.cache.queue", attributes: .concurrent)
    private var lastCleanupTime = Date()
    
    // 统计信息
    private var hitCount = 0
    private var missCount = 0
    
    private init() {
        // 启动定期清理
        startPeriodicCleanup()
    }
    
    /// 获取缓存的置信度
    /// - Parameters:
    ///   - field: 字段名称
    ///   - value: 字段值
    ///   - context: 上下文信息
    /// - Returns: 缓存的置信度，如果没有缓存则返回 nil
    func getCachedConfidence(for field: String, value: String, context: [String: Any] = [:]) -> Double? {
        let key = CacheKey(field: field, value: value, context: context)
        
        return cacheQueue.sync {
            guard let entry = cache[key], !entry.isExpired else {
                missCount += 1
                return nil
            }
            
            // 更新命中次数
            cache[key] = CacheEntry(
                confidence: entry.confidence,
                timestamp: entry.timestamp,
                hitCount: entry.hitCount + 1
            )
            
            hitCount += 1
            return entry.confidence
        }
    }
    
    /// 缓存置信度结果
    /// - Parameters:
    ///   - confidence: 置信度值
    ///   - field: 字段名称
    ///   - value: 字段值
    ///   - context: 上下文信息
    func cacheConfidence(_ confidence: Double, for field: String, value: String, context: [String: Any] = [:]) {
        let key = CacheKey(field: field, value: value, context: context)
        let entry = CacheEntry(confidence: confidence, timestamp: Date(), hitCount: 0)
        
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = entry
            
            // 检查缓存大小并清理
            if self.cache.count > Self.maxCacheSize {
                self.cleanupCache()
            }
        }
    }
    
    /// 获取或计算置信度（带缓存）
    /// - Parameters:
    ///   - field: 字段名称
    ///   - value: 字段值
    ///   - context: 上下文信息
    ///   - calculator: 置信度计算闭包
    /// - Returns: 置信度值
    func getOrCalculateConfidence(
        for field: String,
        value: String,
        context: [String: Any] = [:],
        calculator: () -> Double
    ) -> Double {
        // 先尝试从缓存获取
        if let cachedConfidence = getCachedConfidence(for: field, value: value, context: context) {
            return cachedConfidence
        }
        
        // 缓存未命中，计算新值
        let confidence = calculator()
        
        // 缓存结果
        cacheConfidence(confidence, for: field, value: value, context: context)
        
        return confidence
    }
    
    /// 清除特定字段的缓存
    /// - Parameter field: 字段名称
    func clearCache(for field: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache = self.cache.filter { $0.key.field != field }
        }
    }
    
    /// 清除所有缓存
    func clearAllCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
            self.hitCount = 0
            self.missCount = 0
        }
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    func getCacheStatistics() -> CacheStatistics {
        return cacheQueue.sync {
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
            
            return CacheStatistics(
                cacheSize: cache.count,
                hitCount: hitCount,
                missCount: missCount,
                hitRate: hitRate,
                expiredEntries: cache.values.filter { $0.isExpired }.count
            )
        }
    }
    
    /// 预热缓存
    /// - Parameter commonValues: 常用值列表
    func warmupCache(with commonValues: [String: [String]]) {
        let learningService = ConfidenceLearningService.shared
        
        DispatchQueue.global(qos: .utility).async {
            for (field, values) in commonValues {
                for value in values {
                    let confidence = learningService.getSuggestedConfidence(for: field, value: value)
                    self.cacheConfidence(confidence, for: field, value: value)
                }
            }
            
            print("DEBUG: ConfidenceCacheService - Cache warmed up with \(commonValues.values.flatMap { $0 }.count) entries")
        }
    }
    
    // MARK: - 私有方法
    
    private func cleanupCache() {
        let now = Date()
        
        // 移除过期条目
        cache = cache.filter { !$0.value.isExpired }
        
        // 如果仍然超过限制，移除最少使用的条目
        if cache.count > Self.maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.hitCount < $1.value.hitCount }
            let entriesToRemove = sortedEntries.prefix(cache.count - Self.maxCacheSize)
            
            for (key, _) in entriesToRemove {
                cache.removeValue(forKey: key)
            }
        }
        
        lastCleanupTime = now
        print("DEBUG: ConfidenceCacheService - Cache cleaned up, current size: \(cache.count)")
    }
    
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: Self.cleanupInterval, repeats: true) { _ in
            self.cacheQueue.async(flags: .barrier) {
                if Date().timeIntervalSince(self.lastCleanupTime) >= Self.cleanupInterval {
                    self.cleanupCache()
                }
            }
        }
    }
}

// MARK: - 缓存统计信息结构

struct CacheStatistics {
    let cacheSize: Int
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let expiredEntries: Int
    
    var description: String {
        return """
        Cache Statistics:
        - Size: \(cacheSize)
        - Hits: \(hitCount)
        - Misses: \(missCount)
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Expired Entries: \(expiredEntries)
        """
    }
}

// MARK: - 扩展：常用值预定义

extension ConfidenceCacheService {
    /// 获取常用值用于缓存预热
    static func getCommonValues() -> [String: [String]] {
        return [
            "category": [
                "餐饮", "交通", "购物", "娱乐", "医疗", "教育", "住房", "通讯",
                "工资", "奖金", "投资收益", "其他收入", "未分类"
            ],
            "account": [
                "现金", "支付宝", "微信支付", "银行卡", "信用卡", "未知"
            ],
            "description": [
                "午餐", "晚餐", "早餐", "打车", "地铁", "购物", "电影", "医药费",
                "房租", "水电费", "话费", "网费", "工资", "奖金"
            ]
        ]
    }
}
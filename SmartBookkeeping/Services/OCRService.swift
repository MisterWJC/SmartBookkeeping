//
//  OCRService.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import UIKit
import Vision
import NaturalLanguage

class OCRService {
    // 使用统一的数据管理器
    static let expenseCategories = CategoryDataManager.shared.expenseCategories
    static let incomeCategories = CategoryDataManager.shared.incomeCategories
    static let paymentMethods = CategoryDataManager.shared.paymentMethods

    func recognizeText(from image: UIImage, completion: @escaping (Transaction?) -> Void) {
        // 预处理图片以提高 OCR 识别准确率
        let processedImage = preprocessImage(image)
        
        guard let cgImage = processedImage.cgImage else {
            // 确保在主线程调用回调
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { (request, error) in
            guard error == nil else {
                print("识别错误：\(error!.localizedDescription)")
                // 确保在主线程调用回调
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("无法获取识别结果")
                // 确保在主线程调用回调
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 解析账单详情
            let billDetails = self.parseBillDetails(from: observations)
            
            // 使用 AI 服务处理识别出的文本
            AIService.shared.processText(billDetails.description) { aiResponse in
                if let response = aiResponse {
                    // 使用 BillProcessingService 处理 AI 响应
                    if let transaction = BillProcessingService.shared.processAIResponse(response) {
                        // 确保在主线程调用回调
                        DispatchQueue.main.async {
                            completion(transaction)
                        }
                    } else {
                        // AI 响应处理失败，使用本地解析结果
                        self.fallbackToLocalProcessing(billDetails, completion: completion)
                    }
                } else {
                    // AI 服务失败，使用本地解析结果
                    self.fallbackToLocalProcessing(billDetails, completion: completion)
                }
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("执行识别请求失败：\(error.localizedDescription)")
            // 确保在主线程调用回调
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    /// 仅进行 OCR 识别，返回识别的文本内容
    func recognizeTextOnly(from image: UIImage, completion: @escaping (String?) -> Void) {
        // 预处理图片以提高 OCR 识别准确率
        let processedImage = preprocessImage(image)
        
        guard let cgImage = processedImage.cgImage else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { (request, error) in
            guard error == nil else {
                print("OCR识别错误：\(error!.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("无法获取OCR识别结果")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 提取所有识别的文本
            var recognizedText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                recognizedText += topCandidate.string + "\n"
            }
            
            DispatchQueue.main.async {
                completion(recognizedText.isEmpty ? nil : recognizedText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("执行OCR识别请求失败：\(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    /// 当 AI 服务失败时，使用本地解析结果
    private func fallbackToLocalProcessing(_ billDetails: BillDetails, completion: @escaping (Transaction?) -> Void) {
        // 创建一个简单的 ZhipuAIResponse 对象，用于 BillProcessingService 处理
        let fallbackResponse = ZhipuAIResponse(
            amount: billDetails.amount,
            transaction_time: nil,
            item_description: billDetails.merchant ?? billDetails.description,
            category: billDetails.category,
            transaction_type: "支出", // 默认为支出
            payment_method: billDetails.paymentMethod,
            notes: ""
        )
        
        // 使用 BillProcessingService 处理
        if let transaction = BillProcessingService.shared.processAIResponse(fallbackResponse) {
            // 确保在主线程调用回调
            DispatchQueue.main.async {
                completion(transaction)
            }
        } else {
            // 如果 BillProcessingService 也失败了，创建一个基本的 Transaction
            let basicTransaction = Transaction(
                amount: abs(billDetails.amount ?? 0.0),
                date: billDetails.date ?? Date(),
                category: "未分类",
                description: billDetails.merchant ?? billDetails.description,
                type: .expense,
                paymentMethod: "未知",
                note: ""
            )
            
            // 确保在主线程调用回调
            DispatchQueue.main.async {
                completion(basicTransaction)
            }
        }
    }
    
    // MARK: - 图片预处理
    private func preprocessImage(_ image: UIImage) -> UIImage {
        // 1. 校正图片方向
        let orientationCorrectedImage = correctImageOrientation(image)
        
        // 2. 优化图片尺寸和质量
        let optimizedImage = optimizeImageForOCR(orientationCorrectedImage)
        
        return optimizedImage
    }
    
    private func correctImageOrientation(_ image: UIImage) -> UIImage {
        // 如果图片方向已经正确，直接返回
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return correctedImage
    }
    
    private func optimizeImageForOCR(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048 // 限制最大尺寸以平衡性能和质量
        let size = image.size
        
        // 如果图片已经足够小，直接返回
        if max(size.width, size.height) <= maxDimension {
            return image
        }
        
        // 计算新的尺寸，保持宽高比
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // 创建新的图片
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let optimizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return optimizedImage
    }
    
    private func parseBillDetails(from observations: [VNRecognizedTextObservation]) -> BillDetails {
        var recognizedText = ""
        var potentialAmounts: [Double] = []
        var potentialDates: [Date] = []
        var potentialMerchants: [String] = []
        var potentialCategories: [String] = []
        var potentialPaymentMethods: [String] = []

        // 关键词列表，用于辅助分类和支付方式的识别TODO
        // 支出分类关键词 (可以根据实际账单内容扩展)
        let expenseCategoryKeywords: [String: String] = [
            "数码": "数码电器", "电器": "数码电器", "手机": "数码电器", "电脑": "数码电器",
            "餐饮": "餐饮美食", "美食": "餐饮美食", "饭": "餐饮美食", "餐厅": "餐饮美食", "外卖": "餐饮美食",
            "学习": "自我提升", "课程": "自我提升", "培训": "自我提升",
            "服装": "服装饰品", "饰品": "服装饰品", "衣服": "服装饰品", "鞋": "服装饰品",
            "日用": "日用百货", "百货": "日用百货", "超市": "日用百货",
            "交通": "车辆交通", "公交": "车辆交通", "地铁": "车辆交通", "打车": "车辆交通", "油费": "车辆交通",
            "娱乐": "娱乐休闲", "休闲": "娱乐休闲", "电影": "娱乐休闲", "游戏": "娱乐休闲",
            "医疗": "医疗健康", "健康": "医疗健康", "药": "医疗健康", "医院": "医疗健康",
            "家庭": "家庭支出", "房租": "家庭支出", "水电": "家庭支出",
            "充值": "充值缴费", "缴费": "充值缴费", "话费": "充值缴费",
            "其他": "其他"
        ]
        // 收入分类关键词
        let incomeCategoryKeywords: [String: String] = [
            "副业": "副业收入", "兼职": "副业收入",
            "投资": "投资理财", "理财": "投资理财", "股票": "投资理财", "基金": "投资理财",
            "工资": "主业收入", "薪水": "主业收入",
            "红包": "红包礼金", "礼金": "红包礼金"
        ]
        // 支付方式关键词
        let paymentMethodKeywords: [String: String] = [
            "现金": "现金",
            "招商银行": "招商银行卡", "招行": "招商银行卡",
            "中信银行": "中信银行卡",
            "交通银行": "交通银行卡", "交行": "交通银行卡",
            "建设银行": "建设银行卡", "建行": "建设银行卡",
            "微信": "微信",
            "支付宝": "支付宝",
            "信用卡": "招商信用卡" // 假设招商信用卡是唯一的信用卡选项
        ]

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let text = topCandidate.string
            recognizedText += text + "\n" // For debugging or simpler description

            // --- Amount Extraction (Regex Example) --- 
            let amountRegex = try! NSRegularExpression(pattern: "\\b(?:\\$|€|£|¥)?(\\d{1,3}(?:,\\d{3})*(\\.\\d{2})?)\\b|\\b(\\d+(\\.\\d{2})?)(?:元|円)\\b") // Simplified
            let amountMatches = amountRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in amountMatches {
                if let range = Range(match.range(at: 1), in: text) ?? Range(match.range(at: 3), in: text) {
                    let amountString = String(text[range]).replacingOccurrences(of: ",", with: "")
                    if let amount = Double(amountString) {
                        potentialAmounts.append(amount)
                    }
                }
            }

            // --- Date Extraction (NSDataDetector Example) --- 
            let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let dateMatches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in dateMatches {
                if let date = match.date {
                    potentialDates.append(date)
                }
            }

            // --- Merchant Extraction (Keyword/Position Heuristic - Very Basic) --- 
            // This is highly dependent on bill layout. 
            // For example, if text is at the top and in a larger font. 
            // Or look for keywords like "Ltd.", "Inc.", "Store", "Shop" 
            if observation.boundingBox.maxY > 0.8 && text.count > 3 && text.uppercased() == text { // Simplistic: top of image & all caps 
                potentialMerchants.append(text)
            }

            // --- Category and Payment Method Extraction (Keyword based - Basic) ---
            // 这是一个非常基础的关键词匹配，实际应用中需要更复杂的NLP技术
            for (keyword, category) in expenseCategoryKeywords {
                if text.contains(keyword) {
                    potentialCategories.append(category)
                }
            }
            for (keyword, category) in incomeCategoryKeywords {
                if text.contains(keyword) {
                    // 这里可以根据金额是正是负来判断是收入还是支出，从而决定使用哪个分类列表
                    // 暂时简单添加，后续可以优化
                    potentialCategories.append(category)
                }
            }
            for (keyword, method) in paymentMethodKeywords {
                if text.contains(keyword) {
                    potentialPaymentMethods.append(method)
                }
            }
        }

        // --- Logic to select the best candidates --- 
        let finalAmount = potentialAmounts.max() // Often the largest amount is the total 
        let finalDate = potentialDates.first // Or most recent/relevant 
        let finalMerchant = potentialMerchants.first // Needs more sophisticated logic
        let finalCategory = mostFrequentElement(from: potentialCategories) // 选择最常出现的分类
        let finalPaymentMethod = mostFrequentElement(from: potentialPaymentMethods) // 选择最常出现的支付方式

        // ... further processing for categories, etc. 
        // 根据文本内容关键词判断是收入还是支出，然后从对应的分类列表中选择
        var determinedCategory = finalCategory
        // 使用简单的关键词匹配来确定交易类型
        let defaultTransactionType: Transaction.TransactionType = {
            let text = recognizedText.lowercased()
            if text.contains("收入") || text.contains("转入") || text.contains("入账") {
                return .income
            } else if text.contains("转账") || text.contains("转出") {
                return .transfer
            } else {
                return .expense
            }
        }()
        let categoriesForType = defaultTransactionType == .income ? incomeCategoryKeywords.values : expenseCategoryKeywords.values
        if let category = finalCategory, categoriesForType.contains(category) {
            determinedCategory = category
        } else {
            determinedCategory = "未分类" // 如果匹配不上，则默认为"未分类"
        }

        return BillDetails(amount: finalAmount, date: finalDate, merchant: finalMerchant, category: determinedCategory, paymentMethod: finalPaymentMethod, description: recognizedText /* or a summary */) 
    }
    
    // 辅助函数：找到数组中出现次数最多的元素
    private func mostFrequentElement<T: Hashable>(from array: [T]) -> T? {
        var counts: [T: Int] = [:]
        array.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

struct BillDetails { // Example structure 
    var amount: Double?
    var date: Date?
    var merchant: String?
    var category: String?
    var paymentMethod: String? // 新增支付方式字段
    var description: String
}

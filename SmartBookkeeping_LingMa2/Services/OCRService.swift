//
//  OCRService.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import UIKit
import Vision // 引入 Vision 框架
import NaturalLanguage // For NLP tasks if needed

class OCRService {
    func recognizeText(from image: UIImage, completion: @escaping (Transaction?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { (request, error) in
            guard error == nil else {
                print("识别错误：\(error!.localizedDescription)")
                completion(nil)
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { 
                completion(nil)
                return 
            }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }
            let fullText = recognizedStrings.joined(separator: "\n")
            print("识别结果：\(fullText)")
            
            let billDetails = self.parseBillDetails(from: observations)
            
            // 使用解析后的信息创建Transaction对象
            let transaction = Transaction(
                amount: billDetails.amount ?? 0.0, // 如果解析失败，默认为0
                date: billDetails.date ?? Date(),    // 如果解析失败，默认为当前日期
                category: billDetails.category ?? "未分类", // 如果解析失败，默认为未分类
                description: billDetails.merchant ?? billDetails.description, // 优先使用商户名作为描述
                type: (billDetails.amount ?? 0) >= 0 ? .income : .expense, // 根据金额判断类型
                paymentMethod: billDetails.paymentMethod ?? "未知", // 使用解析出的支付方式
                note: "通过OCR识别: \n" + billDetails.description // 将完整识别文本放入备注
            )
            completion(transaction)
        }
        request.recognitionLevel = .accurate // 精度优先
        request.recognitionLanguages = ["zh-Hans", "en-US"] // 根据需要调整语言
        do {
            try requestHandler.perform([request])
        } catch {
            print("请求执行失败：\(error)")
            completion(nil)
        }
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
        // 根据金额判断是收入还是支出，然后从对应的分类列表中选择
        var determinedCategory = finalCategory
        if let amount = finalAmount {
            let defaultTransactionType: Transaction.TransactionType = amount >= 0 ? .income : .expense // 简单判断
            let categoriesForType = defaultTransactionType == .income ? incomeCategoryKeywords.values : expenseCategoryKeywords.values
            if let category = finalCategory, categoriesForType.contains(category) {
                determinedCategory = category
            } else {
                determinedCategory = nil // 如果匹配不上，则不设定，后续由用户选择
            }
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
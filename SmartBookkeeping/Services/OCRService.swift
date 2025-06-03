//
//  OCRService.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import UIKit
import Vision // 引入 Vision 框架
import NaturalLanguage // For NLP tasks if needed

// 新增：用于解析智谱 API 响应的结构体
struct ZhipuAIResponse: Codable {
    let amount: Double?
    let transaction_time: String?
    let item_description: String?
    let category: String?
    let transaction_type: String?
    let payment_method: String?
    let notes: String?
}

class OCRService {
    // 新增：智谱 API Key，请替换为您自己的 API Key
    private let zhipuAIAPIKey = "6478f55ce43641d99966ed79355c0e6f.OKofLW4z3kFSXGkw" 

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
            print("OCR 识别结果：\(fullText)")
            
            // 调用智谱 API 进行处理
            self.callZhipuAI(with: fullText) { transactionDetails in
                guard let details = transactionDetails else {
                    print("智谱 API 处理失败")
                    // 如果智谱 API 失败，尝试使用本地解析
                    let billDetails = self.parseBillDetails(from: observations)
                    let transactionType = (billDetails.amount ?? 0) >= 0 ? Transaction.TransactionType.income : .expense
                    let transaction = Transaction(
                        amount: billDetails.amount ?? 0.0, 
                        date: billDetails.date ?? Date(),    
                        category: billDetails.category ?? "未分类", 
                        description: billDetails.merchant ?? billDetails.description, 
                        type: transactionType, 
                        paymentMethod: billDetails.paymentMethod ?? "未知", 
                        note: "通过本地OCR识别: \n" + billDetails.description 
                    )
                    completion(transaction)
                    return
                }
                
                // 使用智谱 API 返回的信息创建 Transaction 对象
                let transactionType: Transaction.TransactionType
                switch details.transaction_type?.lowercased() {
                case "收入":
                    transactionType = .income
                case "支出":
                    transactionType = .expense
                default:
                    // 如果智谱未返回明确类型，则根据金额判断，或默认为支出
                    transactionType = (details.amount ?? 0) >= 0 ? .income : .expense
                }
                
                // 解析交易时间
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
                var transactionDate = dateFormatter.date(from: details.transaction_time ?? "") ?? Date() // Default to current date if parsing fails initially

                // 后处理 transaction_time
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                if let year = calendar.dateComponents([.year], from: transactionDate).year {
                    // 如果年份是1970年或者2023年（根据用户反馈，API在未识别日期时可能返回2023年），
                    // 并且这个年份不是当前年份（避免正常记录的2023年数据被错误修改），则视为无效日期，需要修正
                    if (year == 1970 || year == 2023) && year != currentYear {
                        let currentTime = Date()
                        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: currentTime)
                        
                        // 尝试保留原始解析出的小时、分钟、秒，如果它们看起来是有效的
                        // （例如，不是午夜00:00:00，除非原始文本真的就是午夜）
                        // 简单起见，如果API返回的日期是1970或2023，我们优先使用当前时间的时分秒，
                        // 因为原始时间戳的可靠性也存疑。
                        // 如果需要更精细的控制，可以检查原始 transaction_time 字符串中是否包含有效的时间部分。
                        let originalTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: transactionDate)
                        if let originalHour = originalTimeComponents.hour,
                           let originalMinute = originalTimeComponents.minute,
                           let originalSecond = originalTimeComponents.second,
                           !(originalHour == 0 && originalMinute == 0 && originalSecond == 0) { // 如果不是默认的00:00:00
                            dateComponents.hour = originalHour
                            dateComponents.minute = originalMinute
                            dateComponents.second = originalSecond
                        } else {
                            dateComponents.hour = calendar.component(.hour, from: currentTime)
                            dateComponents.minute = calendar.component(.minute, from: currentTime)
                            dateComponents.second = calendar.component(.second, from: currentTime)
                        }
                        transactionDate = calendar.date(from: dateComponents) ?? Date()
                    }
                }

                // 后处理 category
                let expenseCategories = ["数码电器", "餐饮美食", "自我提升", "服装饰品", "日用百货", "车辆交通", "娱乐休闲", "医疗健康", "家庭支出", "充值缴费", "其他"]
                let incomeCategories = ["副业收入", "投资理财", "主业收入", "红包礼金"]
                let targetCategories = transactionType == .expense ? expenseCategories : incomeCategories
                let bestCategory = self.findBestMatch(for: details.category ?? "", from: targetCategories) ?? (transactionType == .expense ? "其他" : "主业收入")

                // 后处理 payment_method
                let paymentMethods = ["现金", "招商银行卡", "中信银行卡", "微信", "支付宝", "招商信用卡", "交通信用卡"]
                var paymentMethodString = details.payment_method ?? ""

                // 首先处理特定关键字的映射
                if paymentMethodString.contains("花呗") || paymentMethodString.contains("余额宝") {
                    paymentMethodString = "支付宝"
                } else if paymentMethodString.contains("零钱") || paymentMethodString.contains("微信支付") { // 避免 "微信" 字符串本身被重复处理
                    paymentMethodString = "微信"
                }
                // 更多银行卡或其他支付方式的别名映射可以加在这里
                // 例如：如果识别到 "建行"、"建设银行"，可以映射到 "建设银行卡"

                let bestPaymentMethod = self.findBestMatch(for: paymentMethodString, from: paymentMethods) ?? "未知"

                let transaction = Transaction(
                    amount: details.amount ?? 0.0,
                    date: transactionDate,
                    category: bestCategory,
                    description: details.item_description ?? "",
                    type: transactionType,
                    paymentMethod: bestPaymentMethod,
                    note: details.notes ?? ""
                )
                completion(transaction)
            }
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

    // 新增：调用智谱 API 的方法
    private func callZhipuAI(with text: String, completion: @escaping (ZhipuAIResponse?) -> Void) {
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(zhipuAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages = [
            ["role": "system", "content": "你是一个智能记账助手，你需要从用户提供的账单文本中提取关键的记账信息，并以JSON格式返回。提取的字段包括：amount (金额，数字类型), transaction_time (交易时间，格式 YYYY年MM月DD日 HH:MM:SS), item_description (商品说明), category (交易分类，从预定义列表中选择), transaction_type (收入/支出), payment_method (付款方式), notes (备注)。"],
            ["role": "user", "content": text]
        ]

        let body: [String: Any] = [
            "model": "glm-4-air-250414",
            "messages": messages,
            "stream": false // 改为 false 以获取完整 JSON 响应
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("创建请求体失败: \(error)")
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("智谱 API 请求错误: \(error?.localizedDescription ?? "未知错误")")
                completion(nil)
                return
            }
            
            // 打印原始响应数据以供调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("智谱 API 原始响应: \(responseString)")
            }

            do {
                // 解析外层结构
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: String],
                   let content = message["content"] {
                    
                    // 再次打印待解析的 content 字符串
                    print("智谱 API content 字符串: \(content)")
                    
                    // 清理 content 字符串，移除可能的 Markdown 标记
                    var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedContent.hasPrefix("```json") {
                        cleanedContent = String(cleanedContent.dropFirst(7))
                    }
                    if cleanedContent.hasSuffix("```") {
                        cleanedContent = String(cleanedContent.dropLast(3))
                    }
                    cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)

                    // 将清理后的 content 字符串解析为 ZhipuAIResponse
                    if let contentData = cleanedContent.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        let zhipuResponse = try decoder.decode(ZhipuAIResponse.self, from: contentData)
                        completion(zhipuResponse)
                    } else {
                        print("无法将 content 转换为 Data")
                        completion(nil)
                    }
                } else {
                    print("解析智谱 API 响应失败：未能找到 'content' 字段或结构不匹配")
                    completion(nil)
                }
            } catch {
                print("解析智谱 API 响应 JSON 失败: \(error)")
                completion(nil)
            }
        }
        task.resume()
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
                determinedCategory = "未分类" // 如果匹配不上，则默认为“未分类”
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

    // 新增：辅助函数，计算 Levenshtein 距离
    private func levenshteinDistance(a: String, b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var dp = Array(repeating: Array(repeating: 0, count: bChars.count + 1), count: aChars.count + 1)

        for i in 0...aChars.count {
            dp[i][0] = i
        }
        for j in 0...bChars.count {
            dp[0][j] = j
        }

        for i in 1...aChars.count {
            for j in 1...bChars.count {
                let cost = (aChars[i-1] == bChars[j-1]) ? 0 : 1
                dp[i][j] = min(
                    dp[i-1][j] + 1,      // Deletion
                    dp[i][j-1] + 1,      // Insertion
                    dp[i-1][j-1] + cost  // Substitution
                )
            }
        }
        return dp[aChars.count][bChars.count]
    }

    // 新增：辅助函数，从列表中找到与输入字符串最相似的字符串
    private func findBestMatch(for input: String, from list: [String]) -> String? {
        guard !input.isEmpty, !list.isEmpty else { return nil }
        var bestMatch: String? = nil
        var minDistance = Int.max

        // 完全匹配优先
        if list.contains(input) {
            return input
        }

        for item in list {
            let distance = levenshteinDistance(a: input, b: item)
            if distance < minDistance {
                minDistance = distance
                bestMatch = item
            }
        }
        // 可以设置一个阈值，例如，如果最小距离大于字符串长度的一半，则认为没有好的匹配
        // 调整阈值，使其更宽松一些，以匹配如 “支付宝付款” 到 “支付宝”
        if let match = bestMatch, minDistance <= (input.count / 2) + 2 { // 容忍一定程度的差异，增加到2
             return match
        }
        return nil
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
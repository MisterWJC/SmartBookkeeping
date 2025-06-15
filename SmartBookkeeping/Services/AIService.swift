import Foundation

class AIService: ObservableObject {
    static let shared = AIService()
    private let configManager = ConfigurationManager.shared
    
    init() {}
    
    private var apiKey: String? {
        return configManager.aiAPIKey
    }
    
    private var baseURL: String {
        return configManager.aiBaseURL
    }
    
    private var modelName: String {
        return configManager.aiModelName
    }
    
    func processText(_ text: String) async throws -> AIResponse {
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            throw AIServiceError.invalidAPIKey
        }
        
        let prompt = """
        # 角色
        你是一个逻辑严谨、经验丰富的财务数据提取专家。你的专长是从非结构化、甚至带有错误的文本（如语音识别稿、OCR扫描件）中，精准地提取结构化的记账信息。

        # 任务
        请深度分析以下【用户输入文本】，忽略所有无关的口语化词汇和干扰信息，并严格按照【输出要求】返回一个纯净的JSON对象。

        # 输出要求
        1.  严格返回一个单一、原始的JSON对象。
        2.  绝不允许包含任何解释性文字、注释、Markdown格式（如```json）或JSON主体之外的任何字符。
        3.  如果【用户输入文本】中完全不包含任何有效的记账信息，则返回一个所有值为 null 的JSON结构。

        **文本:**
        \(text)

        # JSON结构与字段说明
        {
            "amount": Number, // 交易金额，必须是数字。正数代表收入，负数在文本中也应提取为正数，通过 type 字段区分。
            "category": String, // 必须从下方【预设选项列表】中选择最匹配的一项。
            "description": String, // 对交易核心内容的简洁概括，优先使用商品或服务名。
            "date": "YYYY-MM-DD HH:mm:ss", // 交易时间。请将"昨天"等相对时间转换为绝对时间。若无具体时间，默认为"12:00:00"。若无日期，使用1970-01-01。
            "type": String, // 必须是 "收入" 或 "支出"。根据关键词（如“收到”、“花了”）或分类来判断。
            "account": String, // 账户，必须从下方【预设选项列表】中选择最匹配的一项。
            "notes": String // 记录额外但有用的上下文信息。
        }

        # 核心逻辑与规则
        1.  **抗干扰性**: 必须忽略语音识别产生的填充词（如“嗯”、“啊”、“那个”）和OCR的无关文本（如“交易单号”、“优惠说明”）。
        2.  **分类层级**: 分类决策的优先级为：明确的商品名/服务名 > 商户名 > 上下文推断。例如，“在星巴克买了杯拿铁”，分类为“餐饮美食”，描述为“拿铁咖啡”或“星巴克咖啡”。
        3.  **智能映射**: 对分类和支付方式进行模糊匹配。例如，“KFC”、“肯德基”都应映射到“餐饮美食”；“用微信付的”应映射到“微信”。
        4.  **空值处理**: 对于在文本中确实无法找到或推断出的信息（尤其是 `amount` 和 `description`），其值必须为 `null`，而不是空字符串 `""` 或编造的数据。

        # 预设选项列表
        * **支出类别**: ["数码电器", "餐饮美食", "自我提升", "服装饰品", "日用百货", "车辆交通", "娱乐休闲", "医疗健康", "家庭支出", "充值缴费", "其他"]
        * **收入类别**: ["主业收入", "副业收入", "投资理财", "红包礼金", "其他收入"]
        * **支付方式**: ["现金", "招商银行卡", "中信银行卡", "交通银行卡", "建设银行卡", "工商银行卡", "农业银行卡", "中国银行卡", "民生银行卡", "光大银行卡", "夏银行卡", "平安银行卡", "浦发银行卡", "兴业银行卡", "信用卡", "招商信用卡", "建行信用卡", "工行信用卡", "微信", "支付宝", "Apple Pay", "Samsung Pay", "云闪付", "数字人民币", "银行转账", "网银转账", "手机银行"]
        """
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.3
        ]
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0 // 设置30秒超时
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIServiceError.encodingError
        }
        
        do {
            print("DEBUG: AIService - Sending request to: \(url)")
            print("DEBUG: AIService - Request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")
            
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                print("ERROR: AIService - Invalid HTTP response")
                throw AIServiceError.networkError
            }
            
            print("DEBUG: AIService - HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("ERROR: AIService - HTTP Error \(httpResponse.statusCode): \(responseString)")
                // 提供更详细的错误信息
                if httpResponse.statusCode == 401 {
                    throw AIServiceError.invalidAPIKey
                } else if httpResponse.statusCode >= 500 {
                    throw AIServiceError.serverError(httpResponse.statusCode)
                } else {
                    throw AIServiceError.serverError(httpResponse.statusCode)
                }
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "No response data"
            print("DEBUG: AIService - Raw response: \(responseString)")
            
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = jsonResponse["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.invalidResponse
            }
            
            print("DEBUG: AIService - AI response content: \(content)")
            
            // 尝试从content中提取JSON
            let cleanedContent = extractJSONFromContent(content)
            print("DEBUG: AIService - Cleaned JSON content: \(cleanedContent)")
            
            // 解析AI返回的JSON内容
            guard let contentData = cleanedContent.data(using: .utf8),
                  let aiResult = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
                print("ERROR: AIService - Failed to parse AI response JSON")
                throw AIServiceError.parsingError
            }
            
            print("DEBUG: AIService - Parsed AI result: \(aiResult)")
            
            let amount = aiResult["amount"] as? Double ?? 0.0
            let category = aiResult["category"] as? String ?? "其他"
            let description = aiResult["description"] as? String ?? ""
            let dateString = aiResult["date"] as? String ?? ""
            let type = aiResult["type"] as? String ?? "支出"
            let account = aiResult["account"] as? String ?? "默认账户"
            let notes = aiResult["notes"] as? String ?? ""
            
            // 解析日期
            let date = parseDate(from: dateString) ?? Date()
            
            let response = AIResponse(
                amount: amount,
                transaction_time: dateString,
                item_description: description,
                category: category,
                transaction_type: type,
                payment_method: account,
                notes: notes
            )
            
            print("DEBUG: AIService - Created AIResponse: \(response)")
            return response
            
        } catch {
            if error is AIServiceError {
                throw error
            } else if let urlError = error as? URLError {
                if urlError.code == .timedOut {
                    throw AIServiceError.networkError
                } else {
                    throw AIServiceError.networkError
                }
            } else {
                throw AIServiceError.networkError
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractJSONFromContent(_ content: String) -> String {
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除可能的markdown代码块标记
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = String(cleanedContent.dropFirst(7))
        } else if cleanedContent.hasPrefix("```") {
            cleanedContent = String(cleanedContent.dropFirst(3))
        }
        
        if cleanedContent.hasSuffix("```") {
            cleanedContent = String(cleanedContent.dropLast(3))
        }
        
        // 移除JSON中的注释（// 开头的行注释）
        let lines = cleanedContent.components(separatedBy: .newlines)
        let filteredLines = lines.compactMap { line -> String? in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            // 检查是否包含注释
            if let commentIndex = trimmedLine.range(of: "//")?.lowerBound {
                let beforeComment = String(trimmedLine[..<commentIndex]).trimmingCharacters(in: .whitespaces)
                // 如果注释前还有内容，保留注释前的部分
                return beforeComment.isEmpty ? nil : beforeComment
            }
            return trimmedLine.isEmpty ? nil : line
        }
        
        cleanedContent = filteredLines.joined(separator: "\n")
        
        return cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseDate(from dateString: String) -> Date? {
        let formatters = [
            "yyyy年MM月dd日 HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy年MM月dd日",
            "yyyy-MM-dd",
            "yyyy/MM/dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "zh_CN")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

// MARK: - Error Types

enum AIServiceError: Error, LocalizedError {
    case invalidAPIKey
    case invalidURL
    case encodingError
    case networkError
    case serverError(Int)
    case invalidResponse
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API密钥无效或未设置"
        case .invalidURL:
            return "无效的URL"
        case .encodingError:
            return "请求编码失败"
        case .networkError:
            return "网络连接失败，请检查网络设置"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        case .invalidResponse:
            return "服务器响应格式无效"
        case .parsingError:
            return "解析AI响应失败"
        }
    }
}
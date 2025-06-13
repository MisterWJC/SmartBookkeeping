import Foundation

class AIService {
    static let shared = AIService()
    private let configManager = ConfigurationManager.shared
    
    private init() {}
    
    private var apiKey: String? {
        return configManager.zhipuAPIKey
    }
    
    private var baseURL: String {
        return configManager.zhipuBaseURL
    }
    
    func processText(_ text: String, completion: @escaping (ZhipuAIResponse?) -> Void) {
        // 检查API密钥是否已配置
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            print("错误：智谱AI API密钥未配置")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let prompt = """
        请从以下文本中提取交易信息，并以JSON格式返回，包含以下字段：
        - amount: 交易金额（数字）
        - transaction_time: 交易时间（格式：yyyy年MM月dd日 HH:mm:ss）
        - item_description: 商品描述
        - category: 交易类别（必须从以下预定义列表中选择最匹配的）
        - transaction_type: 交易类型（收入/支出）
        - payment_method: 支付方式（必须从以下预定义列表中选择最匹配的）
        - notes: 备注信息

        支出类别选项：数码电器、餐饮美食、自我提升、服装饰品、日用百货、车辆交通、娱乐休闲、医疗健康、家庭支出、充值缴费、其他
        
        收入类别选项：主业收入、副业收入、投资理财、红包礼金、其他收入
        
        支付方式选项：现金、招商银行卡、中信银行卡、交通银行卡、建设银行卡、工商银行卡、农业银行卡、中国银行卡、民生银行卡、光大银行卡、华夏银行卡、平安银行卡、浦发银行卡、兴业银行卡、信用卡、招商信用卡、建行信用卡、工行信用卡、微信、支付宝、Apple Pay、Samsung Pay、云闪付、数字人民币、银行转账、网银转账、手机银行、其他支付
        
        分类规则：
        1. 优先根据商户名称、商品描述进行分类
        2. 如果包含品牌名（如麦当劳、星巴克等）请归类到对应类别
        3. 如果无法确定具体类别，选择"其他"或"其他收入"
        4. 支付方式要根据实际支付渠道选择，如微信支付选择"微信"，银行卡支付选择对应银行
        
        示例：
        - "麦当劳 汉堡套餐" → category: "餐饮美食"
        - "苹果专卖店 iPhone" → category: "数码电器"
        - "滴滴出行 打车费" → category: "车辆交通", payment_method: "微信"
        - "工资发放" → category: "主业收入", transaction_type: "收入"

        文本内容：
        \(text)

        请只返回JSON格式的数据，不要包含其他说明文字。
        """
        
        guard let url = URL(string: baseURL) else {
            // 确保在主线程调用回调
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": "你是一个智能记账助手，你需要从用户提供的账单文本中提取关键的记账信息，并以JSON格式返回。提取的字段包括：amount (金额，数字类型), transaction_time (交易时间，格式 YYYY年MM月DD日 HH:MM:SS), item_description (商品说明), category (交易分类，从预定义列表中选择), transaction_type (收入/支出), payment_method (付款方式), notes (备注)。"],
            ["role": "user", "content": prompt]
        ]

        let requestBody: [String: Any] = [
            "model": "glm-4-air-250414",
            "messages": messages,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            // 确保在主线程调用回调
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                // 确保在主线程调用回调
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                // 确保在主线程调用回调
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("智谱 API 原始响应: \(responseString)")
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: String],
                   let content = message["content"] {
                    
                    print("智谱 API content 字符串: \(content)")
                    
                    var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedContent.hasPrefix("```json") {
                        cleanedContent = String(cleanedContent.dropFirst(7))
                    }
                    if cleanedContent.hasSuffix("```") {
                        cleanedContent = String(cleanedContent.dropLast(3))
                    }
                    cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let contentData = cleanedContent.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        let zhipuResponse = try decoder.decode(ZhipuAIResponse.self, from: contentData)
                        // 确保在主线程调用回调
                        DispatchQueue.main.async {
                            completion(zhipuResponse)
                        }
                        print("AI Response: \(zhipuResponse)")
                    } else {
                        print("无法将 content 转换为 Data")
                        // 确保在主线程调用回调
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                } else {
                    print("解析智谱 API 响应失败：未能找到 'content' 字段或结构不匹配")
                    // 确保在主线程调用回调
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("Decoding error: \(error)")
                // 确保在主线程调用回调
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
}
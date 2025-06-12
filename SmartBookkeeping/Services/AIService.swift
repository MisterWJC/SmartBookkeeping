import Foundation

class AIService {
    static let shared = AIService()
    private let apiKey = "6478f55ce43641d99966ed79355c0e6f.OKofLW4z3kFSXGkw"
    private let baseURL = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    
    private init() {}
    
    func processText(_ text: String, completion: @escaping (ZhipuAIResponse?) -> Void) {
        let prompt = """
        请从以下文本中提取交易信息，并以JSON格式返回，包含以下字段：
        - amount: 交易金额（数字）
        - transaction_time: 交易时间（格式：yyyy年MM月dd日 HH:mm:ss）
        - item_description: 商品描述
        - category: 交易类别
        - transaction_type: 交易类型（收入/支出）
        - payment_method: 支付方式
        - notes: 备注信息

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
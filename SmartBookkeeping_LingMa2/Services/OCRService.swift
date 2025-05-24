//
//  OCRService.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import Foundation
import UIKit
import Vision // 引入 Vision 框架

class OCRService {
    func recognizeText(from image: UIImage, completion: @escaping (Transaction?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                // 返回置信度最高的候选文本
                observation.topCandidates(1).first?.string
            }
            
            // 简单地将所有识别到的文本拼接起来作为描述
            let description = recognizedStrings.joined(separator: "\n")
            
            // 模拟从识别文本中提取交易信息
            // 在实际应用中，这里需要更复杂的逻辑来解析文本并填充交易字段
            let dummyTransaction = Transaction(
                amount: 100.0, // 示例金额
                date: Date(), // 当前日期
                category: "餐饮", // 示例分类
                description: description, // OCR 识别的文本
                type: .expense, // 默认为支出
                paymentMethod: "支付宝", // 示例支付方式
                note: "通过OCR识别"
            )
            completion(dummyTransaction)
        }
        
        // 支持的语言，可以根据需要调整
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.recognitionLevel = .accurate // 可以选择 .fast 或 .accurate

        do {
            try requestHandler.perform([request])
        } catch {
            print("Error performing text recognition: \(error)")
            completion(nil)
        }
    }
}
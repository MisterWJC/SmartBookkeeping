import SwiftUI
import Vision
import VisionKit

class ShortcutManager: ObservableObject {
    @Published var isProcessing = false
    @Published var recognizedText: String = ""
    @Published var processedData: TransactionData?
    @Published var error: String?
    
    func handleShortcutImage(_ imageData: Data) {
        isProcessing = true
        error = nil
        
        // 1. 将图片数据转换为 UIImage
        guard let image = UIImage(data: imageData) else {
            error = "无法处理图片数据"
            isProcessing = false
            return
        }
        
        // 2. 执行 OCR
        performOCR(on: image) { [weak self] result in
            switch result {
            case .success(let text):
                self?.recognizedText = text
                // 3. 使用 Zhipu AI 处理文本
                self?.processWithZhipuAI(text)
            case .failure(let error):
                self?.error = error.localizedDescription
                self?.isProcessing = false
            }
        }
    }
    
    private func performOCR(on image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法处理图片"])))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法识别文本"])))
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(.success(recognizedText))
        }
        
        // 配置 OCR 请求
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }
    
    private func processWithZhipuAI(_ text: String) {
        // TODO: 实现 Zhipu AI 处理逻辑
        // 这里需要调用 Zhipu AI API 处理文本
        // 处理完成后，将结果转换为 TransactionData
        
        // 示例实现：
        let mockData = TransactionData(
            amount: 0,
            category: "",
            date: Date(),
            note: text,
            type: .expense
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.processedData = mockData
            self?.isProcessing = false
        }
    }
    
    func reset() {
        isProcessing = false
        recognizedText = ""
        processedData = nil
        error = nil
    }
} 
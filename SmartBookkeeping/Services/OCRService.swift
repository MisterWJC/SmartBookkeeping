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
    private let categoryManager = CategoryDataManager.shared
    
    // 获取分类的计算属性
    private var expenseCategories: [String] {
        return categoryManager.categories(for: .expense)
    }
    
    private var incomeCategories: [String] {
        return categoryManager.categories(for: .income)
    }
    
    private var paymentMethods: [String] {
        return categoryManager.paymentMethods
    }

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
                paymentMethod: "其他支付",
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
            // 数码电器类
            "数码": "数码电器", "电器": "数码电器", "手机": "数码电器", "电脑": "数码电器",
            "苹果": "数码电器", "华为": "数码电器", "小米": "数码电器", "三星": "数码电器",
            "iPad": "数码电器", "iPhone": "数码电器", "MacBook": "数码电器", "笔记本": "数码电器",
            "耳机": "数码电器", "充电器": "数码电器", "数据线": "数码电器", "音响": "数码电器",
            "相机": "数码电器", "摄像头": "数码电器", "键盘": "数码电器", "鼠标": "数码电器",
            
            // 餐饮美食类
            "餐饮": "餐饮美食", "美食": "餐饮美食", "饭": "餐饮美食", "餐厅": "餐饮美食", "外卖": "餐饮美食",
            "麦当劳": "餐饮美食", "肯德基": "餐饮美食", "星巴克": "餐饮美食", "海底捞": "餐饮美食",
            "美团外卖": "餐饮美食", "饿了么": "餐饮美食", "点餐": "餐饮美食", "聚餐": "餐饮美食",
            "咖啡": "餐饮美食", "奶茶": "餐饮美食", "火锅": "餐饮美食", "烧烤": "餐饮美食",
            "早餐": "餐饮美食", "午餐": "餐饮美食", "晚餐": "餐饮美食", "夜宵": "餐饮美食",
            "快餐": "餐饮美食", "中餐": "餐饮美食", "西餐": "餐饮美食", "日料": "餐饮美食",
            
            // 自我提升类
            "学习": "自我提升", "课程": "自我提升", "培训": "自我提升", "教育": "自我提升",
            "书籍": "自我提升", "图书": "自我提升", "考试": "自我提升", "证书": "自我提升",
            "技能": "自我提升", "语言": "自我提升", "英语": "自我提升", "编程": "自我提升",
            "在线课程": "自我提升", "网课": "自我提升", "知识付费": "自我提升",
            
            // 服装饰品类
            "服装": "服装饰品", "饰品": "服装饰品", "衣服": "服装饰品", "鞋": "服装饰品",
            "优衣库": "服装饰品", "ZARA": "服装饰品", "H&M": "服装饰品", "Nike": "服装饰品",
            "Adidas": "服装饰品", "运动鞋": "服装饰品", "皮鞋": "服装饰品", "凉鞋": "服装饰品",
            "T恤": "服装饰品", "裤子": "服装饰品", "裙子": "服装饰品", "外套": "服装饰品",
            "包包": "服装饰品", "手表": "服装饰品", "首饰": "服装饰品", "帽子": "服装饰品",
            
            // 日用百货类
            "日用": "日用百货", "百货": "日用百货", "超市": "日用百货", "生活用品": "日用百货",
            "沃尔玛": "日用百货", "家乐福": "日用百货", "大润发": "日用百货", "永辉": "日用百货",
            "洗发水": "日用百货", "牙膏": "日用百货", "毛巾": "日用百货", "纸巾": "日用百货",
            "洗衣液": "日用百货", "清洁用品": "日用百货", "化妆品": "日用百货", "护肤品": "日用百货",
            
            // 车辆交通类
            "交通": "车辆交通", "公交": "车辆交通", "地铁": "车辆交通", "打车": "车辆交通", "油费": "车辆交通",
            "滴滴": "车辆交通", "出租车": "车辆交通", "网约车": "车辆交通", "高铁": "车辆交通",
            "火车": "车辆交通", "飞机": "车辆交通", "机票": "车辆交通", "车票": "车辆交通",
            "停车费": "车辆交通", "过路费": "车辆交通", "汽油": "车辆交通", "加油": "车辆交通",
            "维修": "车辆交通", "保养": "车辆交通", "洗车": "车辆交通",
            
            // 娱乐休闲类
            "娱乐": "娱乐休闲", "休闲": "娱乐休闲", "电影": "娱乐休闲", "游戏": "娱乐休闲",
            "KTV": "娱乐休闲", "酒吧": "娱乐休闲", "网吧": "娱乐休闲", "健身": "娱乐休闲",
            "旅游": "娱乐休闲", "景点": "娱乐休闲", "门票": "娱乐休闲", "演出": "娱乐休闲",
            "音乐会": "娱乐休闲", "话剧": "娱乐休闲", "展览": "娱乐休闲", "博物馆": "娱乐休闲",
            "游乐园": "娱乐休闲", "温泉": "娱乐休闲", "按摩": "娱乐休闲", "SPA": "娱乐休闲",
            
            // 医疗健康类
            "医疗": "医疗健康", "健康": "医疗健康", "药": "医疗健康", "医院": "医疗健康",
            "药店": "医疗健康", "诊所": "医疗健康", "体检": "医疗健康", "看病": "医疗健康",
            "挂号": "医疗健康", "检查": "医疗健康", "治疗": "医疗健康", "手术": "医疗健康",
            "药品": "医疗健康", "保健品": "医疗健康", "维生素": "医疗健康", "眼镜": "医疗健康",
            
            // 家庭支出类
            "家庭": "家庭支出", "房租": "家庭支出", "水电": "家庭支出", "物业": "家庭支出",
            "电费": "家庭支出", "水费": "家庭支出", "燃气费": "家庭支出", "网费": "家庭支出",
            "宽带": "家庭支出", "家具": "家庭支出", "装修": "家庭支出", "保险": "家庭支出",
            "房贷": "家庭支出", "车贷": "家庭支出",
            
            // 充值缴费类
            "充值": "充值缴费", "缴费": "充值缴费", "话费": "充值缴费", "流量": "充值缴费",
            "电话费": "充值缴费", "手机费": "充值缴费", "会员": "充值缴费", "VIP": "充值缴费",
            "订阅": "充值缴费", "年费": "充值缴费", "月费": "充值缴费", "服务费": "充值缴费",
            
            // 其他
            "其他": "其他", "未知": "其他", "杂项": "其他"
        ]
        // 收入分类关键词
        let incomeCategoryKeywords: [String: String] = [
            // 主业收入类
            "工资": "主业收入", "薪水": "主业收入", "薪资": "主业收入", "月薪": "主业收入",
            "年终奖": "主业收入", "奖金": "主业收入", "绩效": "主业收入", "提成": "主业收入",
            "津贴": "主业收入", "补贴": "主业收入", "加班费": "主业收入", "出差补助": "主业收入",
            
            // 副业收入类
            "副业": "副业收入", "兼职": "副业收入", "外快": "副业收入", "代购": "副业收入",
            "自媒体": "副业收入", "直播": "副业收入", "带货": "副业收入", "写作": "副业收入",
            "设计": "副业收入", "翻译": "副业收入", "咨询": "副业收入", "培训": "副业收入",
            "网店": "副业收入", "电商": "副业收入", "微商": "副业收入", "代理": "副业收入",
            
            // 投资理财类
            "投资": "投资理财", "理财": "投资理财", "股票": "投资理财", "基金": "投资理财",
            "债券": "投资理财", "期货": "投资理财", "外汇": "投资理财", "黄金": "投资理财",
            "数字货币": "投资理财", "比特币": "投资理财", "以太坊": "投资理财", "虚拟币": "投资理财",
            "房租收入": "投资理财", "租金": "投资理财", "分红": "投资理财", "利息": "投资理财",
            "收益": "投资理财", "盈利": "投资理财", "回报": "投资理财", "收入": "投资理财",
            
            // 红包礼金类
            "红包": "红包礼金", "礼金": "红包礼金", "压岁钱": "红包礼金", "生日红包": "红包礼金",
            "结婚红包": "红包礼金", "满月红包": "红包礼金", "节日红包": "红包礼金", "过年红包": "红包礼金",
            "微信红包": "红包礼金", "支付宝红包": "红包礼金", "转账": "红包礼金", "借款归还": "红包礼金",
            
            // 其他收入
            "退款": "其他收入", "退货": "其他收入", "赔偿": "其他收入", "补偿": "其他收入",
            "奖励": "其他收入", "中奖": "其他收入", "彩票": "其他收入", "抽奖": "其他收入",
            "报销": "其他收入", "退税": "其他收入", "社保": "其他收入", "公积金": "其他收入"
        ]
        // 支付方式关键词
        let paymentMethodKeywords: [String: String] = [
            // 现金
            "现金": "现金", "纸币": "现金", "硬币": "现金",
            
            // 银行卡类
            "招商银行": "招商银行卡", "招行": "招商银行卡", "CMB": "招商银行卡",
            "中信银行": "中信银行卡", "中信": "中信银行卡", "CITIC": "中信银行卡",
            "交通银行": "交通银行卡", "交行": "交通银行卡", "BOCOM": "交通银行卡",
            "建设银行": "建设银行卡", "建行": "建设银行卡", "CCB": "建设银行卡",
            "工商银行": "工商银行卡", "工行": "工商银行卡", "ICBC": "工商银行卡",
            "农业银行": "农业银行卡", "农行": "农业银行卡", "ABC": "农业银行卡",
            "中国银行": "中国银行卡", "中行": "中国银行卡", "BOC": "中国银行卡",
            "民生银行": "民生银行卡", "民生": "民生银行卡", "CMBC": "民生银行卡",
            "光大银行": "光大银行卡", "光大": "光大银行卡", "CEB": "光大银行卡",
            "华夏银行": "华夏银行卡", "华夏": "华夏银行卡", "HXB": "华夏银行卡",
            "平安银行": "平安银行卡", "平安": "平安银行卡", "PAB": "平安银行卡",
            "浦发银行": "浦发银行卡", "浦发": "浦发银行卡", "SPDB": "浦发银行卡",
            "兴业银行": "兴业银行卡", "兴业": "兴业银行卡", "CIB": "兴业银行卡",
            
            // 信用卡类
            "信用卡": "信用卡", "贷记卡": "信用卡", "VISA": "信用卡",
            "MasterCard": "信用卡", "万事达": "信用卡", "银联": "信用卡",
            "招商信用卡": "招商信用卡", "建行信用卡": "建行信用卡", "工行信用卡": "工行信用卡",
            
            // 移动支付类
            "微信": "微信", "微信支付": "微信", "WeChat Pay": "微信", "微信钱包": "微信",
            "支付宝": "支付宝", "Alipay": "支付宝", "蚂蚁支付": "支付宝", "花呗": "支付宝",
            "Apple Pay": "Apple Pay", "苹果支付": "Apple Pay", "ApplePay": "Apple Pay",
            "Samsung Pay": "Samsung Pay", "三星支付": "Samsung Pay",
            "云闪付": "云闪付", "银联云闪付": "云闪付", "UnionPay": "云闪付",
            
            // 其他支付方式
            "京东支付": "其他支付", "美团支付": "其他支付", "滴滴支付": "其他支付",
            "PayPal": "其他支付", "贝宝": "其他支付", "QQ钱包": "其他支付",
            "数字人民币": "数字人民币", "DCEP": "数字人民币", "e-CNY": "数字人民币",
            "转账": "银行转账", "网银": "网银转账", "手机银行": "手机银行"
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

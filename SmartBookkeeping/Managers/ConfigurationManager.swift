import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private let userDefaults = UserDefaults.standard
    private var configData: [String: Any] = [:]
    
    // API配置键
    private enum ConfigKeys {
        static let aiAPIKey = "ai_api_key"
        static let aiBaseURL = "ai_base_url"
        static let aiModelName = "ai_model_name"
        static let freeUsesRemaining = "free_uses_remaining"
    }
    
    // 默认配置（从配置文件读取）
    private var defaultValues: DefaultValues {
        return DefaultValues(configData: configData)
    }
    
    private struct DefaultValues {
        let aiAPIKey: String?
        let aiBaseURL: String
        let aiModelName: String
        let freeUsesRemaining: Int
        
        init(configData: [String: Any]) {
            self.aiAPIKey = configData["DefaultAPIKey"] as? String
            self.aiBaseURL = configData["DefaultBaseURL"] as? String ?? "https://open.bigmodel.cn/api/paas/v4"
            self.aiModelName = configData["DefaultModelName"] as? String ?? "glm-4-air-250414"
            self.freeUsesRemaining = configData["DefaultFreeUses"] as? Int ?? 50
        }
    }
    
    private init() {
        // 加载配置文件
        loadConfigFile()
        // 设置默认值
        setupDefaultValues()
    }
    
    private func loadConfigFile() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let data = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Warning: Config.plist not found, using fallback defaults")
            return
        }
        configData = data
    }
    
    private func setupDefaultValues() {
        if userDefaults.string(forKey: ConfigKeys.aiBaseURL) == nil {
            userDefaults.set(defaultValues.aiBaseURL, forKey: ConfigKeys.aiBaseURL)
        }
        if userDefaults.string(forKey: ConfigKeys.aiModelName) == nil {
            userDefaults.set(defaultValues.aiModelName, forKey: ConfigKeys.aiModelName)
        }
        if userDefaults.string(forKey: ConfigKeys.aiAPIKey) == nil {
            if let defaultAPIKey = defaultValues.aiAPIKey {
                userDefaults.set(defaultAPIKey, forKey: ConfigKeys.aiAPIKey)
            }
        }
        // 初始化免费使用次数（只在第一次启动时设置）
        if userDefaults.object(forKey: ConfigKeys.freeUsesRemaining) == nil {
            userDefaults.set(defaultValues.freeUsesRemaining, forKey: ConfigKeys.freeUsesRemaining)
        }
    }
    
    // MARK: - API配置
    
    /// 获取AI API密钥
    var aiAPIKey: String? {
        get {
            return userDefaults.string(forKey: ConfigKeys.aiAPIKey)
        }
        set {
            userDefaults.set(newValue, forKey: ConfigKeys.aiAPIKey)
        }
    }
    
    /// 获取AI API基础URL
    var aiBaseURL: String {
        get {
            return userDefaults.string(forKey: ConfigKeys.aiBaseURL) ?? defaultValues.aiBaseURL
        }
        set {
            userDefaults.set(newValue, forKey: ConfigKeys.aiBaseURL)
        }
    }
    
    /// 获取AI模型名称
    var aiModelName: String {
        get {
            return userDefaults.string(forKey: ConfigKeys.aiModelName) ?? defaultValues.aiModelName
        }
        set {
            userDefaults.set(newValue, forKey: ConfigKeys.aiModelName)
        }
    }
    
    // MARK: - 兼容性属性（向后兼容）
    
    /// 获取智谱AI API密钥（兼容性属性）
    var zhipuAPIKey: String? {
        get { return aiAPIKey }
        set { aiAPIKey = newValue }
    }
    
    /// 获取智谱AI API基础URL（兼容性属性）
    var zhipuBaseURL: String {
        get { return aiBaseURL }
        set { aiBaseURL = newValue }
    }
    
    /// 检查API配置是否完整
    var isAPIConfigured: Bool {
        return aiAPIKey != nil && !aiAPIKey!.isEmpty
    }
    
    /// 重置API配置
    func resetAPIConfiguration() {
        userDefaults.removeObject(forKey: ConfigKeys.aiAPIKey)
        userDefaults.set(defaultValues.aiBaseURL, forKey: ConfigKeys.aiBaseURL)
        userDefaults.set(defaultValues.aiModelName, forKey: ConfigKeys.aiModelName)
    }
    
    /// 设置默认AI配置
    func setDefaultAIConfiguration() {
        aiBaseURL = defaultValues.aiBaseURL
        aiModelName = defaultValues.aiModelName
    }
    
    /// 设置API配置
    func setAPIConfiguration(apiKey: String, baseURL: String? = nil, modelName: String? = nil) {
        aiAPIKey = apiKey
        if let baseURL = baseURL {
            aiBaseURL = baseURL
        }
        if let modelName = modelName {
            aiModelName = modelName
        }
    }
    
    // MARK: - 免费使用次数管理
    
    /// 获取剩余免费使用次数
    var freeUsesRemaining: Int {
        get {
            return userDefaults.integer(forKey: ConfigKeys.freeUsesRemaining)
        }
        set {
            userDefaults.set(newValue, forKey: ConfigKeys.freeUsesRemaining)
        }
    }
    
    /// 消耗一次免费使用次数
    func consumeFreeUse() {
        let current = freeUsesRemaining
        if current > 0 {
            freeUsesRemaining = current - 1
        }
    }
    
    /// 重置免费使用次数
    func resetFreeUses() {
        freeUsesRemaining = defaultValues.freeUsesRemaining
    }
}
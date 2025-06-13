import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private let userDefaults = UserDefaults.standard
    
    // API配置键
    private enum ConfigKeys {
        static let zhipuAPIKey = "zhipu_api_key"
        static let zhipuBaseURL = "zhipu_base_url"
    }
    
    // 默认配置
    private enum DefaultValues {
        static let zhipuBaseURL = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    }
    
    private init() {
        // 设置默认值
        setupDefaultValues()
    }
    
    private func setupDefaultValues() {
        if userDefaults.string(forKey: ConfigKeys.zhipuBaseURL) == nil {
            userDefaults.set(DefaultValues.zhipuBaseURL, forKey: ConfigKeys.zhipuBaseURL)
        }
    }
    
    // MARK: - API配置
    
    /// 获取智谱AI API密钥
    var zhipuAPIKey: String? {
        get {
            return userDefaults.string(forKey: ConfigKeys.zhipuAPIKey)
        }
        set {
            userDefaults.set(newValue, forKey: ConfigKeys.zhipuAPIKey)
        }
    }
    
    /// 获取智谱AI API基础URL
    var zhipuBaseURL: String {
        get {
            return userDefaults.string(forKey: ConfigKeys.zhipuBaseURL) ?? DefaultValues.zhipuBaseURL
        }
        set {
            userDefaults.set(newValue, forKey: ConfigKeys.zhipuBaseURL)
        }
    }
    
    /// 检查API配置是否完整
    var isAPIConfigured: Bool {
        return zhipuAPIKey != nil && !zhipuAPIKey!.isEmpty
    }
    
    /// 重置API配置
    func resetAPIConfiguration() {
        userDefaults.removeObject(forKey: ConfigKeys.zhipuAPIKey)
        userDefaults.set(DefaultValues.zhipuBaseURL, forKey: ConfigKeys.zhipuBaseURL)
    }
    
    /// 设置API配置
    func setAPIConfiguration(apiKey: String, baseURL: String? = nil) {
        zhipuAPIKey = apiKey
        if let baseURL = baseURL {
            zhipuBaseURL = baseURL
        }
    }
}
import SwiftUI

struct APIConfigurationView: View {
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    private let configManager = ConfigurationManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("智谱AI配置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API密钥")
                            .font(.headline)
                        SecureField("请输入智谱AI API密钥", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("获取API密钥：访问 https://open.bigmodel.cn")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API基础URL")
                            .font(.headline)
                        TextField("API基础URL", text: $baseURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("默认URL已自动填充，通常无需修改")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("保存配置") {
                        saveConfiguration()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("重置配置", role: .destructive) {
                        resetConfiguration()
                    }
                }
                
                Section(header: Text("当前状态")) {
                    HStack {
                        Text("配置状态")
                        Spacer()
                        Text(configManager.isAPIConfigured ? "已配置" : "未配置")
                            .foregroundColor(configManager.isAPIConfigured ? .green : .red)
                    }
                }
            }
            .navigationTitle("API配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentConfiguration()
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCurrentConfiguration() {
        apiKey = configManager.zhipuAPIKey ?? ""
        baseURL = configManager.zhipuBaseURL
    }
    
    private func saveConfiguration() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedAPIKey.isEmpty else {
            alertMessage = "请输入API密钥"
            showAlert = true
            return
        }
        
        // 验证URL格式
        if !trimmedBaseURL.isEmpty {
            guard URL(string: trimmedBaseURL) != nil else {
                alertMessage = "请输入有效的URL格式"
                showAlert = true
                return
            }
        }
        
        configManager.setAPIConfiguration(
            apiKey: trimmedAPIKey,
            baseURL: trimmedBaseURL.isEmpty ? nil : trimmedBaseURL
        )
        
        alertMessage = "配置保存成功"
        showAlert = true
        
        // 延迟关闭视图
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func resetConfiguration() {
        configManager.resetAPIConfiguration()
        loadCurrentConfiguration()
        alertMessage = "配置已重置"
        showAlert = true
    }
}

#Preview {
    APIConfigurationView()
}
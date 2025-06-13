import SwiftUI

struct APISetupView: View {
    @State private var apiKey: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Binding var isPresented: Bool
    
    private let configManager = ConfigurationManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("欢迎使用智能记账")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("为了使用AI功能，请先配置智谱AI API密钥")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("API密钥")
                        .font(.headline)
                    
                    SecureField("请输入智谱AI API密钥", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("如何获取API密钥：")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("1. 访问 https://open.bigmodel.cn")
                        Text("2. 注册并登录账户")
                        Text("3. 在控制台创建API密钥")
                        Text("4. 复制密钥并粘贴到上方输入框")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button("开始使用") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("稍后配置") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("初始设置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {
                    if alertMessage.contains("成功") {
                        isPresented = false
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveConfiguration() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedAPIKey.isEmpty else {
            alertMessage = "请输入API密钥"
            showAlert = true
            return
        }
        
        configManager.setAPIConfiguration(apiKey: trimmedAPIKey)
        
        alertMessage = "配置保存成功！现在可以使用AI功能了。"
        showAlert = true
    }
}

#Preview {
    APISetupView(isPresented: .constant(true))
}
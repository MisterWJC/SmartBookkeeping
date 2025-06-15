# API配置功能说明

## 概述

为了提高代码安全性和灵活性，智能记账应用现在支持可配置的API密钥。用户可以在应用中设置自己的智谱AI API密钥，而不再使用硬编码的密钥。

## 功能特性

### 1. 配置管理器 (ConfigurationManager)
- 使用 UserDefaults 安全存储API配置
- 支持API密钥和基础URL的配置
- 提供配置状态检查功能
- 支持配置重置功能

### 2. API配置界面 (APIConfigurationView)
- 用户友好的配置界面
- 安全的密钥输入（使用SecureField）
- 实时配置状态显示
- URL格式验证
- 配置保存和重置功能

### 3. 初始设置引导 (APISetupView)
- 应用首次启动时的API配置引导
- 详细的API密钥获取说明
- 可选择稍后配置

### 4. 集成到现有界面
- 在"我的"页面添加API配置入口
- 配置状态可视化指示器
- 与现有功能无缝集成

## 使用方法

### 首次使用
1. 启动应用后，如果未配置API密钥，会自动显示设置引导
2. 访问 https://open.bigmodel.cn 获取API密钥
3. 在应用中输入API密钥
4. 点击"开始使用"完成配置

### 后续管理
1. 进入"我的"页面
2. 点击"API配置"按钮
3. 可以查看、修改或重置API配置
4. 配置状态会实时显示（绿色勾号表示已配置，红色感叹号表示未配置）

## 安全性改进

### 之前的问题
- API密钥硬编码在源代码中
- 存在安全风险，密钥可能被泄露
- 无法灵活更换API密钥

### 现在的解决方案
- API密钥存储在用户设备的UserDefaults中
- 不再在源代码中暴露敏感信息
- 用户可以使用自己的API密钥
- 支持密钥的动态更新

## 技术实现

### 文件结构
```
SmartBookkeeping/
├── Managers/
│   └── ConfigurationManager.swift     # 配置管理器
├── Views/
│   ├── APIConfigurationView.swift     # API配置界面
│   ├── APISetupView.swift             # 初始设置引导
│   └── ProfileView.swift              # 更新的个人页面
├── Services/
│   └── AIService.swift                # 更新的AI服务
└── ContentView.swift                  # 更新的主视图
```

### 主要修改
1. **AIService.swift**: 移除硬编码API密钥，从ConfigurationManager获取
2. **ConfigurationManager.swift**: 新增配置管理功能
3. **APIConfigurationView.swift**: 新增API配置界面
4. **APISetupView.swift**: 新增初始设置引导
5. **ProfileView.swift**: 添加API配置入口
6. **ContentView.swift**: 添加初始化检查逻辑

## 错误处理

- 当API密钥未配置时，AI功能会返回错误并提示用户配置
- 提供清晰的错误信息和解决方案
- 支持配置验证和格式检查

## 用户体验

- 首次使用时自动引导配置
- 配置状态可视化显示
- 简单直观的配置界面
- 支持稍后配置的灵活性

## 注意事项

1. **API密钥安全**: 请妥善保管您的API密钥，不要分享给他人
2. **网络连接**: 使用AI功能需要网络连接
3. **API额度**: 请注意您的API使用额度，避免超出限制
4. **备份配置**: 建议记录您的API密钥，以便在需要时重新配置

## 故障排除

### 常见问题
1. **AI功能无法使用**: 检查API密钥是否正确配置
2. **配置丢失**: 重新进入API配置页面设置
3. **网络错误**: 检查网络连接和API密钥有效性

### 解决方案
1. 进入"我的" > "API配置"检查配置状态
2. 重新输入正确的API密钥
3. 如有问题，可以使用"重置配置"功能重新开始
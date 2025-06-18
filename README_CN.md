# 智能记账助手
智能记账 App，让你的账本，越用越懂你。

## 核心功能

### 🎯 AI 智能化
*   **AI 置信度系统：** 先进的AI系统，从用户行为中学习，提供智能交易分类和置信度评分
*   **智能文本识别：** 基于智谱AI (GLM-4) 的强大能力，准确提取各种文本输入中的交易详情
*   **语音转交易：** 实时语音识别，将口述的交易详情转换为结构化数据

### 📱 核心功能
*   **OCR 票据扫描：** 使用 Vision 框架自动从票据图像中提取交易详情
*   **语音录制与识别：** 通过语音记录交易详情并自动进行AI处理
*   **手动记账与编辑：** 手动添加和编辑交易记录，包含完整的表单验证
*   **智能快速输入：** AI驱动的快速输入，处理自然语言交易描述
*   **交易历史记录：** 查看和管理全面的交易记录，支持高级筛选
*   **分类管理：** 智能分类系统，预设支出和收入分类
*   **支付方式跟踪：** 支持多种支付方式，包括数字钱包和银行卡

### 📊 数据与分析
*   **实时处理：** 即时AI处理交易数据，提供置信度评分
*   **数据持久化：** 使用 Core Data 进行安全的本地存储，支持完整的增删改查操作
*   **导出功能：** 支持将交易数据导出为 CSV/Excel 格式进行外部分析
*   **月度汇总：** 自动计算收入和支出总额

### 🔧 用户体验
*   **引导式入门：** 交互式教程展示AI功能
*   **可配置AI设置：** 用户可配置API密钥和AI模型参数
*   **多模态输入：** 支持语音、文本和图像的交易录入方式
*   **实时验证：** 为所有用户输入提供即时反馈和错误处理

## 快速开始

### 系统要求
*   Xcode 15.0 或更高版本
*   iOS 16.0 或更高版本
*   智谱AI API密钥（用于AI功能）

### 安装步骤
1.  克隆仓库：
    ```bash
    git clone https://github.com/your-username/SmartBookkeeping.git
    cd SmartBookkeeping
    ```
2.  在 Xcode 中打开 `SmartBookkeeping.xcodeproj`
3.  在应用设置中配置您的智谱AI API密钥
4.  在模拟器或真机上构建并运行应用

### 配置说明

#### API 密钥配置
为了保护敏感信息，本项目使用配置文件来管理 API 密钥和其他配置信息。

**设置步骤：**
1. **复制示例配置文件**
   ```bash
   cp SmartBookkeeping/Config.example.plist SmartBookkeeping/Config.plist
   ```

2. **编辑配置文件**
   打开 `SmartBookkeeping/Config.plist` 文件，将 `YOUR_API_KEY_HERE` 替换为你的实际 API 密钥：
   ```xml
   <key>DefaultAPIKey</key>
   <string>你的实际API密钥</string>
   ```

3. **获取 API 密钥**
   - 访问 [智谱AI开放平台](https://open.bigmodel.cn/)
   - 注册账号并获取 API 密钥
   - 将密钥填入配置文件

**配置文件说明：**

- `Config.example.plist` - 示例配置文件（可以提交到版本控制）

**默认配置：**
如果没有找到 `Config.plist` 文件，应用会使用以下默认值：
- Base URL: `https://open.bigmodel.cn/api/paas/v4`
- Model Name: `glm-4-air-250414`
- Free Uses: `50`
- API Key: 无（需要用户手动配置）

#### 其他设置
*   **AI API 设置：** 在 设置 > API配置 中配置您的智谱AI API密钥（备选方法）
*   **权限设置：** 授予麦克风和相册访问权限以获得完整功能
*   **分类设置：** 自定义交易分类以匹配您的消费模式

## 技术栈

### 核心框架
*   **SwiftUI** - 现代声明式UI框架
*   **Core Data** - 本地数据持久化和管理
*   **Vision 框架** - 图像OCR文本识别
*   **Speech 框架** - 实时语音识别
*   **AVFoundation** - 音频录制和处理

### AI 与机器学习
*   **智谱AI (GLM-4)** - 用于交易数据提取的大语言模型
*   **自定义AI置信度系统** - 专有的置信度评分算法
*   **自然语言处理** - 高级文本解析和分类

### 架构与模式
*   **MVVM 架构** - 清晰的关注点分离
*   **Combine 框架** - 响应式编程数据流
*   **Swift Package Manager** - 依赖管理
*   **协调器模式** - 导航和流程管理

## 产品 MVP

- **UI 设计和演示视频：** 您可以在 `SmartBookkeeping-PRD/Presentations/` 目录中找到产品MVP的UI文档和演示视频。
    - [SmartBookkeeping_MVP.pdf](./SmartBookkeeping-PRD/Presentations/SmartBookkeeping_MVP.pdf)
    - <video src="https://github.com/user-attachments/assets/7e212281-2918-4653-983e-b1096b40c1fe" controls width="600">
      </video>

## 💖 支持项目

如果这个项目对您有帮助，欢迎请我喝杯咖啡 ☕

### 微信赞赏码
<img src="./SmartBookkeeping-PRD/images/ali_reward.JPG" width="200" alt="微信赞赏码">

### 支付宝收款码  
<img src="./SmartBookkeeping-PRD/images/wechat_reward.JPG" width="200" alt="支付宝收款码">

### 其他支持方式
- ⭐ 给项目点个Star
- 🐛 提交Issue或PR
- 📢 推荐给更多朋友
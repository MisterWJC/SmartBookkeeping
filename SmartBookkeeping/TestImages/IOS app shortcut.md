# IOS app 连接快捷指令

好的，要实现图中所示的快捷指令，核心在于你的 App 需要能与快捷指令 App 进行交互。这主要通过苹果的 **App Intents** 框架来实现。

整个过程分为两大部分：**App 开发** 和 **快捷指令制作**。

---

### ## 1. App 开发（你需要做的事情）

你的 App 需要定义一个“动作（Action）”，让快捷指令 App 能够发现并使用它。这个动作就是图中的“识别账单”。

### **核心技术：App Intents 框架**

这是苹果推荐的最新框架，用于将 App 的功能暴露给系统，如快捷指令、Siri 和聚焦搜索。

### **具体步骤：**

1. **定义一个 App Intent**
你需要在你的 App 项目中创建一个新的 Swift 文件，并定义一个遵循 `AppIntent` 协议的结构体（struct）。这个结构体就代表了“识别账单”这个动作。
    
    ```swift
    import AppIntents
    import SwiftUI
    
    // 定义“识别账单”这个动作
    struct RecognizeBillIntent: AppIntent {
        // 定义快捷指令中显示的标题
        static var title: LocalizedStringResource = "识别账单"
        // （可选）定义描述
        static var description: IntentDescription = IntentDescription("从一张图片中识别账单信息。")
    
        // 1. 定义输入参数：图片
        // 使用 @Parameter 标记这是一个输入参数
        // IntentFile 类型用于接收文件，比如图片、文档等
        @Parameter(title: "图片", supportedTypeIdentifiers: ["public.image"])
        var image: IntentFile
    
        // 2. 定义动作的核心逻辑
        // 这是当快捷指令运行到这一步时，你的 App 会执行的代码
        @MainActor
        func perform() async throws -> some IntentResult {
            // 从输入的 image (IntentFile) 中读取图片数据
            let imageData = try await image.read()
            guard let uiImage = UIImage(data: imageData) else {
                // 如果图片数据无效，可以抛出错误
                throw NSError(domain: "com.yourapp.error", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法读取图片"])
            }
    
            // 在这里编写你自己的账单识别代码
            // 例如：使用 OCR (光学字符识别) 技术来提取文本、金额、日期等
            // let recognizedText = performOCR(on: uiImage)
            // let amount = parseAmount(from: recognizedText)
            // ...
    
            // 3. 返回结果（可选）
            // 你可以返回处理后的数据，以便在快捷指令的下一步中使用
            // 比如，返回一个包含金额和日期的字符串
            let resultValue = "账单识别完成！" // 这里应替换为真实识别结果
            return .result(value: resultValue)
        }
    }
    
    ```
    
2. **向系统“宣告”你的动作**
你需要告诉系统，你的 App 提供了上述这个动作。这通过创建一个遵循 `AppShortcutsProvider` 协议的对象来完成。
    
    ```swift
    import AppIntents
    
    struct MyAppShortcuts: AppShortcutsProvider {
        static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: RecognizeBillIntent(),
                phrases: [
                    "用 \\(.applicationName) 识别账单", // 用户可以通过 Siri 这样说
                    "识别图片中的账单"
                ],
                shortTitle: "识别账单",
                systemImageName: "doc.text.magnifyingglass" // 在快捷指令中显示的图标
            )
        }
    }
    
    ```
    
3. **处理图片数据**
在 `perform()` 方法中，你已经通过 `image.read()` 获取到了快捷指令传入的截图的二进制数据 (`Data`)。接下来，你需要：
    - 将 `Data` 转换为 `UIImage` 或 `CGImage`。
    - 调用你自己的图像处理或机器学习模型（通常是 OCR）来分析图片，提取关键信息（如商家、金额、日期、商品列表等）。这部分是你的 App 的核心功能和价值所在。

### **总结：App 端需要做什么？**

- **集成 `AppIntents` 框架。**
- **定义一个 `AppIntent`** 来描述你的功能（接收一张图片）。
- **在 `perform()` 方法中实现核心逻辑**：接收图片数据，并调用你的 OCR 或其他识别引擎进行处理。
- **通过 `AppShortcutsProvider` 将你的 Intent 暴露给系统。**

---

### ## 2. 快捷指令制作（用户需要做的事情）

一旦你开发好并安装了含有上述功能的 App，任何用户（包括你自己）就可以在“快捷指令”App 中创建如图所示的工作流。

1. **打开“快捷指令”App**，点击右上角的“+”号创建一个新的快捷指令。
2. **添加“截屏”动作**：在下方的搜索框中搜索并添加“截屏”动作。
3. **找到你的 App 动作**：在搜索框中搜索你的 **App 名称** 或你定义的动作标题 **“识别账单”**。
4. **添加你的动作**：将“识别账单”动作拖到“截屏”动作的下方。
5. **连接数据**：这是最关键的一步。
    - 快捷指令会自动尝试连接。你会看到“识别账单”动作的“图片”参数栏中，自动填入了一个名为**“截屏”**的“魔法变量”。
    - 这表示“截屏”动作的**输出结果**（截取到的图片）被自动用作了“识别账单”动作的**输入**。
    - 如果未自动连接，可以手动点击该参数栏，然后从变量选择器中选择“截屏”。
6. **（可选）添加辅助动作**：
    - **隐藏控制中心**：在“截屏”前添加此动作，可以避免截图中出现控制中心界面。
    - **等待**：在“隐藏控制中心”和“截屏”之间加入一个短暂的“等待”（例如 1 秒），确保界面已完全切换干净。

最终，你就搭建了和图中完全一致的快捷指令。当运行这个快捷指令时，它会自动截图，并将图片传递给你的 App 进行后台处理。
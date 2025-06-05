# 智能记账助手 iOS App - 开发设计文档

## 1. 引言

本文档基于《智能记账助手 MVP - 产品需求文档 (PRD)》和《智能记账助手 App 核心功能定义》制定，旨在为“智能记账助手” iOS App的开发提供技术指导和设计规范。

## 2. 项目概述

智能记账助手是一款旨在简化用户记账流程的iOS应用，其核心功能是通过OCR技术智能识别支付凭证截图，并提供手动记账、账单管理、收支汇总及数据导出等功能。

## 3. 技术选型

*   **开发语言：** Swift
*   **用户界面 (UI)：** SwiftUI (推荐，现代且声明式的UI框架，适合快速开发和迭代)
    *   *备选：* UIKit (如果团队对UIKit更熟悉或有特定UIKit组件需求)
*   **架构模式：** MVVM (Model-View-ViewModel) - 有助于分离业务逻辑和UI，提高代码的可测试性和可维护性。
*   **本地数据存储：** Core Data (Apple官方框架，与SwiftUI集成良好，功能强大)
*   **截图OCR识别：**
    *   **方案A (首选 - 本地处理)：** Vision Framework (iOS内置框架，支持文本识别，无需联网，保护用户隐私)
*   **数据导出：**
    *   CSV: 通过将数据格式化为逗号分隔的字符串并写入文件。
    *   Excel: 可以考虑使用第三方库（如 `CoreXLSX` 或类似库）来生成 `.xlsx` 文件，或者引导用户通过CSV在Numbers或Excel中打开。
*   **依赖管理：** Swift Package Manager (SPM)

## 4. 架构设计

采用MVVM架构，主要分层如下：

*   **Model (模型层)：**
    *   定义核心数据结构，如账单 (`Transaction`)、分类 (`Category`) 等。
    *   负责数据的持久化（通过Core Data）和业务逻辑处理。
    *   包含OCR识别结果的解析逻辑。
*   **View (视图层)：**
    *   使用SwiftUI构建用户界面。
    *   负责展示数据和接收用户交互。
    *   视图应保持“哑”状态，不包含业务逻辑。
*   **ViewModel (视图模型层)：**
    *   作为View和Model之间的桥梁。
    *   从Model层获取数据，并将其转换为View可展示的格式。
    *   处理View的用户输入，调用Model层的业务逻辑。
    *   通过 `@Published` 属性包装器或 `ObservableObject` 协议与View进行数据绑定。

**模块划分 (基于核心功能)：**

*   **OCRService：** 封装截图识别逻辑，使用Vision Framework。
*   **PersistenceService/DataController：** 封装Core Data的初始化、数据存取（增删改查）操作。
*   **TransactionViewModel：** 处理账单的创建、编辑、列表展示逻辑。
*   **CategoryViewModel：** 处理固定分类的获取和选择逻辑。
*   **SummaryViewModel：** 处理收支汇总逻辑。
*   **ExportService：** 处理数据导出为CSV/Excel的逻辑。
*   **SettingsViewModel：** (若有) 处理应用设置相关逻辑。

## 5. 数据模型 (Core Data Entities)

**1. Transaction (账单)**

*   `id`: UUID (主键, 自动生成)
*   `amount`: Double (金额)
*   `date`: Date (交易日期和时间)
*   `transactionDescription`: String? (商品说明/备注)
*   `isExpense`: Bool (是否为支出，true为支出，false为收入)
*   `paymentMethod`: String? (付款/收款方式)
*   `createdAt`: Date (记录创建时间, 自动生成)
*   `updatedAt`: Date (记录更新时间, 自动更新)
*   `originalImageIdentifier`: String? (可选，用于关联原始截图，例如PHAsset的localIdentifier)
*   `category`: Relationship to `Category` (多对一)

**2. Category (交易分类)**

*   `id`: UUID (主键, 自动生成)
*   `name`: String (分类名称，如餐饮美食、交通出行)
*   `isExpenseType`: Bool (该分类是支出类型还是收入类型)
*   `iconName`: String? (可选，用于UI展示的图标名称)
*   `transactions`: Relationship to `Transaction` (一对多，inverse relationship)

**初始化固定分类：**
App首次启动时，需要预置PRD中定义的固定支出和收入分类到Category实体中。

## 6. 核心功能实现思路

**1. 截图智能识别记账**

1.  **权限请求：** 首次使用时请求相册访问权限。
2.  **图片获取：**
    *   通过 `PHPickerViewController` (iOS 14+) 或 `UIImagePickerController` (旧版) 让用户从相册选择截图。
    *   监控剪贴板：App激活时，检查 `UIPasteboard.general.image` 是否为新截图，提示用户是否使用。
3.  **OCR处理 (Vision Framework)：**
    *   创建 `VNImageRequestHandler` 处理选定的 `UIImage`。
    *   创建 `VNRecognizeTextRequest` 进行文本识别。
    *   解析 `VNRecognizedTextObservation` 结果，获取识别出的文本块及其位置。
4.  **信息提取与预填充：**
    *   根据关键词（如“金额”、“付款”、“收款”、“微信支付”、“支付宝”）和文本格式（如日期格式、金额格式）从OCR结果中提取关键信息。
    *   尝试匹配固定交易分类。
    *   预填充到账单编辑界面。
5.  **用户确认与保存：** 用户检查并可修改识别结果，保存到Core Data。

**2. 手动记账与编辑**

*   提供表单界面，用户输入金额、选择日期、分类、收支类型等。
*   编辑时，加载已有账单数据到表单，用户修改后保存。

**3. 账单列表展示**

*   使用 `List` 和 `ForEach` (SwiftUI) 展示账单。
*   通过 `@FetchRequest` (Core Data与SwiftUI集成) 获取并排序账单数据（按 `date` 降序）。
*   每行概要显示日期、分类、金额、简要说明。
*   点击条目可导航到账单详情页（或直接编辑）。

**4. 固定交易分类**

*   在记账/编辑界面提供 `Picker` (SwiftUI) 让用户从预设的 `Category` 列表中选择。
*   `Category` 数据从Core Data加载。

**5. 基础收支汇总**

*   在首页或专门的汇总页面展示。
*   通过 `FetchRequest` 筛选当月（或指定时间范围）的账单。
*   分别计算总支出 (`isExpense == true`) 和总收入 (`isExpense == false`)。

**6. 本地数据存储 (Core Data)**

*   创建 `NSPersistentContainer` 来管理Core Data堆栈。
*   定义 `NSManagedObject` 子类对应上述数据模型。
*   封装常用的数据操作方法（增、删、改、查）。

**7. 数据导出 (CSV/Excel)**

*   **CSV：**
    1.  获取用户选择的时间范围内的账单数据。
    2.  构建CSV头部 (如 `日期,分类,金额,收/支,说明,付款方式`)。
    3.  遍历账单数据，将每个字段转换为字符串，用逗号分隔，换行符分隔记录。
    4.  将生成的CSV字符串写入临时文件。
    5.  使用 `UIActivityViewController` 分享或保存文件。
*   **Excel：**
    *   如果使用第三方库，按照库的API将数据填充到工作表并保存。
    *   如果仅导出CSV，可提示用户用Excel打开。

## 7. 用户流程与界面草图 (简要)

(此部分可根据PRD中的用户流程图，结合iOS平台特性进行细化，例如使用NavigationStack进行页面导航，Modal presentación等)

*   **启动与权限 -> 首页 (含当月汇总与记账入口) -> 截图选择 -> OCR识别与账单预填充/编辑 -> 保存**
*   **首页 -> 手动记账 -> 保存**
*   **首页 -> 账单列表 -> 账单详情/编辑/删除**
*   **首页/设置 -> 数据导出 -> 选择格式与范围 -> 分享/保存**

## 8. 错误处理与边界条件

参考PRD文档中“边界条件和异常处理”部分，针对iOS平台特性进行具体实现：

*   **OCR识别失败：** 提示用户手动输入，或优化识别参数。
*   **Core Data错误：** 捕获 `NSError`，向用户显示友好提示，记录错误日志。
*   **权限未授予：** 引导用户到系统设置开启权限。
*   **网络错误 (若使用云OCR)：** 使用 `URLSession` 错误处理机制，提示用户检查网络。
*   **存储空间不足：** 文件写入或数据库操作失败时，提示用户清理空间。

## 9. (MVP后) 迭代方向

*   自定义分类
*   预算管理
*   iCloud同步
*   小组件 (Widgets)
*   快捷指令 (Siri Shortcuts) 集成
*   更详细的报表分析

## 10. Xcode项目结构 (初步建议)

```
SmartBookkeepingAssistant/
├── SmartBookkeepingAssistantApp.swift  // App Entry Point
├── Assets.xcassets                   // 资源文件
├── Preview Content                   // SwiftUI预览资源
├── CoreDataModels/                   // Core Data模型文件 (.xcdatamodeld)
│   └── SmartBookkeepingAssistant.xcdatamodeld
├── Models/                           // 数据模型 (structs, enums, CoreData NSManagedObject subclasses)
│   ├── Transaction+CoreDataClass.swift
│   └── Category+CoreDataClass.swift
├── ViewModels/
│   ├── TransactionViewModel.swift
│   ├── SummaryViewModel.swift
│   └── ...
├── Views/
│   ├── MainView.swift                // 主界面/首页
│   ├── AddTransactionView.swift      // 添加/编辑账单界面
│   ├── TransactionListView.swift     // 账单列表
│   └── ...
├── Services/
│   ├── OCRService.swift
│   ├── PersistenceController.swift   // Core Data 管理器
│   └── ExportService.swift
├── Utilities/                        // 工具类、扩展
└── Info.plist
```

此文档将作为iOS App开发的起点，并随着开发的进行持续更新和完善。
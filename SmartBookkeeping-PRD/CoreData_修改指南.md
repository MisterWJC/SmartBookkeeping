# Core Data 模型修改指南

## 问题描述

在将应用从 UserDefaults 迁移到 Core Data 后，出现了以下编译错误：

1. `TransactionEntity` 类型找不到 - 已修复为使用 `TransactionItem`
2. `TransactionItem` 实体中缺少 `type` 属性，但在代码中使用了该属性

## 解决方案

### 0. 创建Core data 模型
打开 Xcode，在项目导航器中创建新文件，文件选择File from template，然后选择 IOS > Core Data > Data Model.
创建完 Core Data 模型文件 `SmartBookkeeping_LingMa2.xcdatamodeld`，并修改 Entity 名为 `TransactionItem` 实体。
添加 attributes 以及对应的 types。


### 1. 在 Core Data 模型中添加 `type` 属性

请按照以下步骤在 Xcode 中修改 Core Data 模型：

1. 在 Xcode 中打开项目
2. 在项目导航器中找到并点击 `SmartBookkeeping_LingMa2.xcdatamodeld` 文件（位于 Models 文件夹中）
3. 在编辑器中，你会看到 `TransactionItem` 实体
4. 右键点击 `TransactionItem` 实体，选择 "Add Attribute"
5. 将新属性命名为 `type`，类型设置为 `String`
6. 保存模型文件

### 2. 修改后的 Core Data 模型应包含以下属性

`TransactionItem` 实体应包含以下属性：

- `amount`: Double
- `category`: String
- `date`: Date
- `desc`: String
- `id`: UUID
- `note`: String
- `paymentMethod`: String
- `timestamp`: Date
- `type`: String (新添加)

### 3. 其他已修复的问题

- 已将 `TransactionViewModel.swift` 中的所有 `TransactionEntity` 引用替换为 `TransactionItem`
- 已修复 `PersistenceController.swift` 中的 `details` 属性引用为 `desc`

## 完成这些修改后，应用应该能够正常编译和运行。
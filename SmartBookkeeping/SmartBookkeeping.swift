//
//  SmartBookkeeping_App.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI
import AppIntents

@main
struct SmartBookkeeping_App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var shortcutManager = ShortcutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(shortcutManager)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        print("=== 主应用 URL 处理调试信息 ===")
        print("收到 URL: \(url)")
        print("URL scheme: \(url.scheme ?? "无")")
        print("URL path: \(url.path)")
        print("URL absoluteString: \(url.absoluteString)")
        
        // 处理从分享扩展传入的 URL
        if url.absoluteString.hasPrefix("smartbookkeeping://fromShareExtension") {
            print("处理分享扩展 URL")
            handleShareExtensionURL()
            return
        }
        
        // 处理编辑页面 URL
        if url.absoluteString.hasPrefix("smartbookkeeping://") && url.path == "/edit" {
            print("处理编辑页面 URL")
            handleEditURL(url)
            return
        }
        
        // 处理其他 URL Scheme
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // 处理带有 imagepath 参数的 URL
            if let imagePath = components.queryItems?.first(where: { $0.name == "imagepath" })?.value,
               let decodedPath = imagePath.removingPercentEncoding {
                let fileURL = URL(fileURLWithPath: decodedPath)
                handleImageURL(fileURL)
            } else {
                print("URL 解析失败或未找到 imagepath 参数")
            }
        }
    }
    
    private func handleShareExtensionURL() {
        // 从 App Group 中读取共享图片
        let appGroupID = "group.com.jason.smartbookkeeping"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("shared_image.png")
            handleImageURL(fileURL)
        }
    }
    
    private func handleEditURL(_ url: URL) {
        print("=== 编辑 URL 处理调试信息 ===")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("无法解析编辑 URL 参数")
            return
        }
        
        print("URL 组件解析成功，查询项数量: \(queryItems.count)")
        
        // 解析 URL 参数
        var transactionData: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                transactionData[item.name] = value
                print("参数: \(item.name) = \(value)")
            }
        }
        
        print("解析的交易数据: \(transactionData)")
        
        // 将数据传递给 ShortcutManager
        shortcutManager.handleEditURLData(transactionData)
        print("数据已传递给 ShortcutManager")
    }
    
    private func handleImageURL(_ fileURL: URL) {
        if let imageData = try? Data(contentsOf: fileURL) {
            // 将图片数据传递给 ShortcutManager 进行后续处理
            shortcutManager.handleShortcutImage(imageData)
            print("图片数据长度: \(imageData.count)")
            
            // 处理完成后，可以删除临时文件
            try? FileManager.default.removeItem(at: fileURL)
        } else {
            print("无法读取图片数据，路径：\(fileURL)")
        }
    }
}

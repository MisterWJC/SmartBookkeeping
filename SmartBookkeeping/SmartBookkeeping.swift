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
        print("收到 URL: \(url)")
        
        // 处理从分享扩展传入的 URL
        if url.absoluteString.hasPrefix("smartbookkeeping://fromShareExtension") {
            handleShareExtensionURL()
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

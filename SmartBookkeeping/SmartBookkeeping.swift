//
//  SmartBookkeeping_App.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

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
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let imagePath = components.queryItems?.first(where: { $0.name == "imagepath" })?.value,
                       let decodedPath = imagePath.removingPercentEncoding {
                        let fileURL = URL(fileURLWithPath: decodedPath)
                        if let imageData = try? Data(contentsOf: fileURL) {
                            // 将图片数据传递给 ShortcutManager 进行后续处理
                            shortcutManager.handleShortcutImage(imageData)
                            print("图片数据长度: \(imageData.count)")
                        } else {
                            print("无法读取图片数据，路径：\(fileURL)")
                        }
                    } else {
                        print("URL 解析失败或未找到 imagepath 参数")
                    }
                }
        }
    }
}

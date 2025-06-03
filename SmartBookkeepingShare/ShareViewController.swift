//
//  ShareViewController.swift
//  SmartBookkeepingShare
//
//  Created by JasonWang on 2025/5/27.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        handleIncomingImage()
    }

    private func handleIncomingImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (item, error) in
                    if let url = item as? URL, let imageData = try? Data(contentsOf: url) {
                        // 1. 保存图片到 App Group
                        self.saveImageToAppGroup(imageData: imageData)
                        // 2. 唤起主 App
                        self.openMainApp()
                    } else if let image = item as? UIImage, let imageData = image.pngData() {
                        self.saveImageToAppGroup(imageData: imageData)
                        self.openMainApp()
                    } else {
                        print("无法获取图片数据")
                    }
                    // 3. 关闭扩展
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
                break
            }
        }
    }

    private func saveImageToAppGroup(imageData: Data) {
        // 你的 App Group Identifier
        let appGroupID = "group.com.yourcompany.smartbookkeeping"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("shared_image.png")
            try? imageData.write(to: fileURL)
        }
    }

    private func openMainApp() {
        // 用 URL Scheme 唤起主 App
        let url = URL(string: "smartbookkeeping://fromShareExtension")!
        var responder = self as UIResponder?
        while responder != nil {
            if let application = responder as? UIApplication {
                application.performSelector(onMainThread: Selector(("openURL:")), with: url, waitUntilDone: false)
                break
            }
            responder = responder?.next
        }
    }
}

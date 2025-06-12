//
//  AppShortcutsProvider.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import AppIntents
import SwiftUI

struct SmartBookkeepingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // 注册「识别账单」快捷指令
        AppShortcut(
            intent: RecognizeBillIntent(),
            phrases: [
                "用 \(.applicationName) 识别账单",
                "\(.applicationName) 扫描账单",
                "\(.applicationName) 记录账单",
                "\(.applicationName) 智能记账",
                "\(.applicationName) 识别账单",
                "用 \(.applicationName) 识别账单"
            ],
            shortTitle: "识别账单",
            systemImageName: "doc.text.viewfinder"
        )
    }
}
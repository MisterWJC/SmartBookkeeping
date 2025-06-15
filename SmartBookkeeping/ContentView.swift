//
//  ContentView.swift
//  SmartBookkeeping
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var shortcutManager: ShortcutManager
    @State private var selectedTab = 0
    @State private var showingInitialSetup = false
    
    private let categoryManager = CategoryDataManager.shared
    private let configManager = ConfigurationManager.shared

    init() {
        // Initialize transactionViewModel in init. 
        // We get the viewContext from the PersistenceController singleton here.
        // This ensures that the ViewModel is initialized with a valid context when ContentView is created.
        self._transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionFormView(context: viewContext, transactionViewModel: transactionViewModel)
                .tabItem {
                    Label("记账", systemImage: "pencil.and.scribble")
                }
                .tag(0)
            
            DetailTabView(viewModel: transactionViewModel)
                .tabItem {
                    Label("明细", systemImage: "list.bullet")
                }
                .tag(1)
            
            ChartView(viewModel: transactionViewModel) // 传递 viewModel
                .tabItem {
                    Label("统计", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .environmentObject(transactionViewModel) // 确保 ProfileView 能访问 ViewModel
                .tag(3)
        }
        .onChange(of: shortcutManager.shouldShowEditForm) { shouldShow in
            if shouldShow {
                // 切换到记账页面
                selectedTab = 0
            }
        }
        .onAppear {
            checkInitialSetup()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAIGuide"))) { _ in
            showingInitialSetup = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToDetailTab"))) { _ in
            selectedTab = 1 // 切换到明细页面
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToFormTab"))) { _ in
            selectedTab = 0 // 切换到记账页面
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowEmptyStateGuide"))) { _ in
            // 切换到明细页面显示空状态引导
            selectedTab = 1
        }
        .sheet(isPresented: $showingInitialSetup) {
            InitialSetupView()
                .interactiveDismissDisabled(false) // 允许用户手动关闭
        }
    }
    
    private func checkInitialSetup() {
        if !categoryManager.hasCompletedInitialSetup() {
            showingInitialSetup = true
        }
    }
}

#Preview {
    ContentView()
}

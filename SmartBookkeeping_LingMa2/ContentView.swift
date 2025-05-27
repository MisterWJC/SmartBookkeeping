//
//  ContentView.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var transactionViewModel: TransactionViewModel

    init() {
        // Initialize transactionViewModel in init. 
        // We get the viewContext from the PersistenceController singleton here.
        // This ensures that the ViewModel is initialized with a valid context when ContentView is created.
        self._transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        TabView {
            TransactionFormView(viewModel: transactionViewModel)
                .tabItem {
                    Label("记账", systemImage: "pencil.and.scribble")
                }
            
            TransactionHistoryView(viewModel: transactionViewModel)
                .tabItem {
                    Label("明细", systemImage: "list.bullet")
                }
            
            ChartView(viewModel: transactionViewModel) // 传递 viewModel
                .tabItem {
                    Label("统计", systemImage: "chart.pie.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .environmentObject(transactionViewModel) // 确保 ProfileView 能访问 ViewModel
        }
    }
}

#Preview {
    ContentView()
}

//
//  ContentView.swift
//  SmartBookkeeping_LingMa2
//
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var transactionViewModel = TransactionViewModel()
    
    var body: some View {
        TransactionFormView(viewModel: transactionViewModel)
    }
}

#Preview {
    ContentView()
}

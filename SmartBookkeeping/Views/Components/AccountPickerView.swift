//
//  AccountPickerView.swift
//  SmartBookkeeping
//
//  Created by Jason Wang on 2024/12/19.
//

import SwiftUI
import CoreData

struct AccountPickerView: View {
    @Binding var selectedAccount: String
    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var transactionViewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(selectedAccount: Binding<String>) {
        self._selectedAccount = selectedAccount
        self._transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("选择账户")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                // 账户列表
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(accountViewModel.accounts, id: \.id) { account in
                            accountRowView(account: account)
                        }
                        
                        // 添加新账户按钮
                        NavigationLink(destination: AccountEditView(account: nil, transactionViewModel: transactionViewModel)) {
                            addAccountButtonContent
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 底部按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("完成")
                        .frame(maxWidth: .infinity) // 将所有修饰符移到 Text 上
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            accountViewModel.fetchAccounts()
            // 监听账户创建通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AccountCreated"),
                object: nil,
                queue: .main
            ) { _ in
                accountViewModel.fetchAccounts()
            }
        }
        .onDisappear {
            // 移除通知监听
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AccountCreated"), object: nil)
        }
    }
    

    
    private func accountRowView(account: AccountItem) -> some View {
        HStack(spacing: 16) {
            accountIconView(for: account)
            accountInfoView(for: account)
            Spacer()
            selectionIndicator(for: account)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(selectedAccount == (account.name ?? "") ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            selectedAccount = account.name ?? ""
            dismiss()
        }
    }
    
    private func accountIconView(for account: AccountItem) -> some View {
        Image(systemName: getAccountIcon(for: account.name ?? ""))
            .font(.title2)
            .foregroundColor(.blue)
            .frame(width: 32, height: 32)
    }
    
    private func accountInfoView(for account: AccountItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.name ?? "未知账户")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(account.accountCategory ?? "其他")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func selectionIndicator(for account: AccountItem) -> some View {
        if selectedAccount == (account.name ?? "") {
            Image(systemName: "checkmark")
                .foregroundColor(.blue)
                .font(.body)
                .fontWeight(.semibold)
        }
    }
    

    
    private var addAccountButtonContent: some View {
        HStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 32, height: 32)
            
            Text("添加新账户")
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getAccountIcon(for accountName: String) -> String {
        let name = accountName.lowercased()
        
        if name.contains("现金") || name.contains("cash") {
            return "banknote"
        } else if name.contains("微信") || name.contains("wechat") {
            return "message.circle"
        } else if name.contains("支付宝") || name.contains("alipay") {
            return "a.circle"
        } else if name.contains("银行") || name.contains("bank") || name.contains("卡") {
            return "creditcard"
        } else if name.contains("储蓄") || name.contains("存款") {
            return "building.columns"
        } else {
            return "wallet.pass"
        }
    }
}

#Preview {
    AccountPickerView(selectedAccount: .constant("现金"))
}
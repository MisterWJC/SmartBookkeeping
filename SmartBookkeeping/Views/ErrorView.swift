//
//  ErrorView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2024/01/01.
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("出现错误")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
        }
        .padding()
    }
}

// 网络错误专用视图
struct NetworkErrorView: View {
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("网络连接失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("请检查网络连接后重试")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
        }
        .padding()
    }
}

// API密钥错误视图
struct APIKeyErrorView: View {
    let settingsAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("API密钥无效")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("请检查AI服务的API密钥设置")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: settingsAction) {
                HStack {
                    Image(systemName: "gear")
                    Text("前往设置")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
        }
        .padding()
    }
}

#Preview {
    VStack {
        ErrorView(error: NSError(domain: "TestError", code: 0, userInfo: [NSLocalizedDescriptionKey: "这是一个测试错误消息"])) {
            print("重试")
        }
        
        Divider()
            .padding()
        
        NetworkErrorView {
            print("网络重试")
        }
        
        Divider()
            .padding()
        
        APIKeyErrorView {
            print("前往设置")
        }
    }
}
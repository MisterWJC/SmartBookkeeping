//
//  ImagePicker.swift
//  SmartBookkeeping
//  
//  Created by JasonWang on 2025/5/24.
//

import SwiftUI
import PhotosUI // 引入 PhotosUI 框架

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images // 只选择图片
        config.selectionLimit = 1 // 最多选择一张图片
        config.preferredAssetRepresentationMode = .current // 使用当前表示模式
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        
        // 禁用辅助功能相关的自动化功能来避免AX Lookup错误
        picker.modalPresentationStyle = .fullScreen
        
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 无需更新
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // 立即关闭选择器
            picker.dismiss(animated: true)
            
            // 检查是否有选择结果
            guard !results.isEmpty,
                  let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            // 异步加载图片
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self?.parent.image = image
                    }
                }
            }
        }
    }
}
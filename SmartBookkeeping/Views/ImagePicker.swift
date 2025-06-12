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
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
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
            // 首先检查是否有选择结果
            let hasResults = !results.isEmpty
            
            // 先关闭选择器，并在完成后处理结果
            picker.dismiss(animated: true) { [weak self] in
                guard let self = self, hasResults else { return }
                
                guard let provider = results.first?.itemProvider else { return }
                
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                        // 确保在主线程更新UI，并添加延迟以避免视图控制器冲突
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.parent.image = image as? UIImage
                        }
                    }
                }
            }
        }
    }
}
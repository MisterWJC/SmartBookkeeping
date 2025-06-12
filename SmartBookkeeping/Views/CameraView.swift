import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // 检查相机是否可用
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            // 如果相机不可用，显示提示并关闭相机视图
            DispatchQueue.main.async {
                showAlert = true
                presentationMode.wrappedValue.dismiss()
            }
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 先获取图片
            let capturedImage = info[.originalImage] as? UIImage
            
            // 先关闭相机视图
            picker.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                
                // 在关闭完成后，延迟更新图片，避免视图控制器冲突
                if let image = capturedImage {
                    // 添加延迟以确保视图控制器已完全关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.parent.image = image
                    }
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // 直接使用 picker 的 dismiss 方法关闭视图，避免使用 presentationMode
            picker.dismiss(animated: true)
        }
    }
}
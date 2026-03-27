//
//  ImageDataService.swift
//  NewGrayTemplate
//
//  Created by Assistant on 16.09.2025.
//

import UIKit
import Foundation

class ImageDataService {
    static let shared = ImageDataService()
    
    private init() {}
    
    /// Конвертує data URL в UIImage
    /// - Parameter dataURL: data URL у форматі "data:image/png;base64,..."
    /// - Returns: UIImage або nil якщо конвертація не вдалася
    func imageFromDataURL(_ dataURL: String) -> UIImage? {
        // Перевіряємо чи це data URL
        guard dataURL.hasPrefix("data:image/") else { return nil }
        
        // Знаходимо початок base64 даних
        guard let commaRange = dataURL.range(of: ",") else { return nil }
        let base64String = String(dataURL[commaRange.upperBound...])
        
        // Декодуємо base64
        guard let imageData = Data(base64Encoded: base64String) else { return nil }
        
        return UIImage(data: imageData)
    }
    
    /// Показує iOS Share Sheet для зображення
    /// - Parameters:
    ///   - image: UIImage для поділу
    ///   - sourceView: View з якого показувати Share Sheet (для iPad)
    func shareImage(_ image: UIImage, from sourceView: UIView) {
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Для iPad потрібно вказати popover
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        // Знаходимо поточний view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingViewController = rootViewController
            while let presented = presentingViewController.presentedViewController {
                presentingViewController = presented
            }
            
            presentingViewController.present(activityViewController, animated: true)
        }
    }
    
}

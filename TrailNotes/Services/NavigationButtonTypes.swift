//
//  NavigationButtonTypes.swift
//  NewGrayTemplate
//
//  Created by Assistant on 17.09.2025.
//

import Foundation

// MARK: - Navigation Button Type
enum NavigationButtonType: String, CaseIterable {
    case back = "chevron.backward"
    case forward = "chevron.forward" 
    case home = "house"
    case reload = "arrow.clockwise"
    case share = "square.and.arrow.up"
    case bookmark = "bookmark"
    case close = "xmark"
    case settings = "gearshape.fill"
    
    var accessibilityLabel: String {
        switch self {
        case .back: return "Назад"
        case .forward: return "Вперед"
        case .home: return "Головна"
        case .reload: return "Оновити"
        case .share: return "Поділитися"
        case .bookmark: return "Закладки"
        case .close: return "Закрити"
        case .settings: return "Налаштування"
        }
    }
}

// MARK: - Navigation Button Configuration
struct NavigationButtonConfig {
    let type: NavigationButtonType
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void
    
    init(type: NavigationButtonType, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.type = type
        self.systemImage = type.rawValue
        self.isEnabled = isEnabled
        self.action = action
    }
}

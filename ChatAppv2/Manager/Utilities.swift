//
//  Utilities.swift
//  ChatAppv2
//
//  Created by Hlwan Aung Phyo on 9/6/24.
//

import Foundation
import UIKit


final class Utilities{
    
    static let shared = Utilities()
    private init(){}
    
    
    @MainActor
    func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        let controller = controller ?? UIApplication.shared.keyWindow?.rootViewController
        
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
        
    }
    
}


extension Date {
    func formatRelativeTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        
        let now = Date()
        let difference = Calendar.current.dateComponents([.day], from: self, to: now).day ?? 0
        
        if difference == 0 {
            // Today: Show time
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: self)
        } else if difference == 1 {
            // Yesterday
            return "Yesterday"
        } else if difference < 7 {
            // Within a week: Show day name
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            return dayFormatter.string(from: self)
        } else {
            // More than a week ago: Show date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yy"
            return dateFormatter.string(from: self)
        }
    }
}

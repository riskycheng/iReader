import Foundation
import UIKit

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let defaults = UserDefaults.standard
    
    private let fontSizeKey = "userFontSize"
    
    private init() {
        print("UserDefaultsManager 初始化")
    }
    
    func saveFontSize(_ size: CGFloat) {
        print("===== 字体大小保存操作 =====")
        print("准备保存字体大小: \(size)")
        defaults.set(Double(size), forKey: fontSizeKey)
        let success = defaults.synchronize()
        print("同步状态: \(success ? "成功" : "失败")")
        print("当前保存的字体大小: \(getFontSize())")
        print("========================")
    }
    
    func getFontSize() -> CGFloat {
        print("===== 获取字体大小 =====")
        let size = CGFloat(defaults.double(forKey: fontSizeKey))
        if size == 0 {
            print("未找到保存的字体大小，返回默认值: 20")
            return 20
        }
        print("读取到保存的字体大小: \(size)")
        print("=====================")
        return size
    }
    
    func hasStoredFontSize() -> Bool {
        print("===== 检查字体大小存储状态 =====")
        let hasStored = defaults.object(forKey: fontSizeKey) != nil
        print("是否有保存的字体大小: \(hasStored)")
        print("==============================")
        return hasStored
    }
} 
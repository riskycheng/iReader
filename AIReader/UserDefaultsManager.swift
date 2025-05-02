import Foundation
import UIKit
import SwiftUI

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let defaults = UserDefaults.standard
    
    private let fontSizeKey = "userFontSize"
    private let fontFamilyKey = "userFontFamily"
    private let selectedBackgroundColorIndexKey = "selectedBackgroundColorIndex"
    
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
    
    func saveFontFamily(_ fontFamily: String) {
        print("===== 字体系列保存操作 =====")
        print("准备保存字体系列: \(fontFamily)")
        defaults.set(fontFamily, forKey: fontFamilyKey)
        let success = defaults.synchronize()
        print("同步状态: \(success ? "成功" : "失败")")
        print("当前保存的字体系列: \(getFontFamily())")
        print("========================")
    }
    
    func getFontFamily() -> String {
        print("===== 获取字体系列 =====")
        if let fontFamily = defaults.string(forKey: fontFamilyKey) {
            print("读取到保存的字体系列: \(fontFamily)")
            print("=====================")
            return fontFamily
        }
        print("未找到保存的字体系列，返回默认值: PingFang SC")
        print("=====================")
        return "PingFang SC"
    }
    
    func hasStoredFontFamily() -> Bool {
        print("===== 检查字体系列存储状态 =====")
        let hasStored = defaults.object(forKey: fontFamilyKey) != nil
        print("是否有保存的字体系列: \(hasStored)")
        print("==============================")
        return hasStored
    }
    
    func saveSelectedBackgroundColorIndex(_ index: Int) {
        print("===== 背景颜色选择保存操作 =====")
        print("准备保存背景颜色索引: \(index)")
        defaults.set(index, forKey: selectedBackgroundColorIndexKey)
        let success = defaults.synchronize()
        print("同步状态: \(success ? "成功" : "失败")")
        print("========================")
    }
    
    func getSelectedBackgroundColorIndex() -> Int {
        print("===== 获取背景颜色索引 =====")
        let index = defaults.integer(forKey: selectedBackgroundColorIndexKey)
        print("读取到保存的背景颜色索引: \(index)")
        print("=====================")
        return index
    }
} 

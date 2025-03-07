import Foundation

public struct AppConfig: Codable {
    let status: String
    let version: String
    let features: Features
    let settings: Settings
    
    public struct Features: Codable {
        let activateBookStore: Bool
        
        enum CodingKeys: String, CodingKey {
            case activateBookStore = "activate_book_store"
        }
    }
    
    public struct Settings: Codable {
        let timeout: Int
        let retryCount: Int
        
        enum CodingKeys: String, CodingKey {
            case timeout
            case retryCount = "retry_count"
        }
    }
}

public class ConfigManager {
    public static let shared = ConfigManager()
    
    private var config: AppConfig?
    private let configFileName = "app_config.json"
    private let remoteConfigURL = "https://gitee.com/riskycheng/AppRemoteConfig/raw/master/iReader_config.json"
    private let lastFetchTimeKey = "lastConfigFetchTime"
    private let fetchIntervalInHours: TimeInterval = 24 // 每24小时检查一次远程配置
    
    private init() {
        loadConfig()
    }
    
    func loadConfig() {
        print("\n===== 开始加载配置 =====")
        // 首先尝试从远程URL加载配置文件
        if shouldFetchRemoteConfig() {
            print("需要获取远程配置，开始异步加载...")
            Task {
                if let remoteConfig = await loadConfigFromRemote() {
                    self.config = remoteConfig
                    print("从远程URL加载配置成功")
                    print("远程配置状态: \(remoteConfig.status)")
                    print("远程配置版本: \(remoteConfig.version)")
                    print("远程配置书城激活状态: \(remoteConfig.features.activateBookStore)")
                    print("远程配置超时设置: \(remoteConfig.settings.timeout)")
                    print("远程配置重试次数: \(remoteConfig.settings.retryCount)")
                    
                    // 保存到文档目录
                    saveConfigToDocuments(remoteConfig)
                    
                    // 更新最后获取时间
                    updateLastFetchTime()
                    
                    // 通知UI更新
                    NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
                    return
                } else {
                    print("从远程URL加载配置失败，尝试本地配置")
                    fallbackToLocalConfig()
                }
            }
        } else {
            print("不需要获取远程配置，使用本地配置")
            fallbackToLocalConfig()
        }
    }
    
    private func fallbackToLocalConfig() {
        // 尝试从文档目录加载配置文件
        if let documentsConfig = loadConfigFromDocuments() {
            self.config = documentsConfig
            print("从文档目录加载配置成功")
            printConfigDetails(documentsConfig, source: "文档目录")
            return
        }
        
        // 如果文档目录没有配置文件，则从应用包中加载默认配置
        if let bundleConfig = loadConfigFromBundle() {
            self.config = bundleConfig
            print("从应用包加载配置成功")
            printConfigDetails(bundleConfig, source: "应用包")
            
            // 将默认配置复制到文档目录
            saveConfigToDocuments(bundleConfig)
            return
        }
        
        // 如果都没有找到配置文件，则创建默认配置
        let defaultConfig = createDefaultConfig()
        self.config = defaultConfig
        print("创建默认配置")
        printConfigDetails(defaultConfig, source: "默认配置")
        
        // 保存默认配置到文档目录
        saveConfigToDocuments(defaultConfig)
    }
    
    private func printConfigDetails(_ config: AppConfig, source: String) {
        print("\n===== \(source)配置详情 =====")
        print("状态: \(config.status)")
        print("版本: \(config.version)")
        print("书城激活状态: \(config.features.activateBookStore)")
        print("超时设置: \(config.settings.timeout)")
        print("重试次数: \(config.settings.retryCount)")
        print("===========================\n")
    }
    
    private func shouldFetchRemoteConfig() -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: lastFetchTimeKey)
        let currentTime = Date().timeIntervalSince1970
        let hoursSinceLastFetch = (currentTime - lastFetchTime) / 3600
        
        print("上次获取远程配置时间: \(Date(timeIntervalSince1970: lastFetchTime))")
        print("距离上次获取已经过去: \(hoursSinceLastFetch) 小时")
        print("是否需要获取远程配置: \(lastFetchTime == 0 || hoursSinceLastFetch >= fetchIntervalInHours)")
        
        return lastFetchTime == 0 || hoursSinceLastFetch >= fetchIntervalInHours
    }
    
    private func updateLastFetchTime() {
        let currentTime = Date().timeIntervalSince1970
        UserDefaults.standard.set(currentTime, forKey: lastFetchTimeKey)
        print("更新最后获取时间: \(Date(timeIntervalSince1970: currentTime))")
    }
    
    private func loadConfigFromRemote() async -> AppConfig? {
        print("\n===== 开始从远程URL加载配置 =====")
        print("远程配置URL: \(remoteConfigURL)")
        
        guard let url = URL(string: remoteConfigURL) else {
            print("远程配置URL无效")
            return nil
        }
        
        do {
            print("开始请求远程配置...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("远程配置响应无效")
                return nil
            }
            
            print("远程配置响应状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("远程配置请求失败，状态码: \(httpResponse.statusCode)")
                return nil
            }
            
            print("远程配置请求成功，开始解析...")
            
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            
            print("远程配置解析成功")
            print("远程配置状态: \(config.status)")
            print("远程配置版本: \(config.version)")
            print("远程配置书城激活状态: \(config.features.activateBookStore)")
            print("远程配置超时设置: \(config.settings.timeout)")
            print("远程配置重试次数: \(config.settings.retryCount)")
            print("===========================\n")
            
            return config
        } catch {
            print("从远程加载配置失败: \(error)")
            return nil
        }
    }
    
    private func loadConfigFromDocuments() -> AppConfig? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法访问文档目录")
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(configFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("文档目录中不存在配置文件")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            return config
        } catch {
            print("从文档目录加载配置失败: \(error)")
            return nil
        }
    }
    
    private func loadConfigFromBundle() -> AppConfig? {
        guard let fileURL = Bundle.main.url(forResource: "app_config", withExtension: "json") else {
            print("应用包中不存在配置文件")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            return config
        } catch {
            print("从应用包加载配置失败: \(error)")
            return nil
        }
    }
    
    private func createDefaultConfig() -> AppConfig {
        return AppConfig(
            status: "active",
            version: "1.0",
            features: AppConfig.Features(activateBookStore: true),
            settings: AppConfig.Settings(timeout: 30, retryCount: 3)
        )
    }
    
    private func saveConfigToDocuments(_ config: AppConfig) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法访问文档目录")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(configFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: fileURL)
            print("配置已保存到文档目录: \(fileURL.path)")
        } catch {
            print("保存配置到文档目录失败: \(error)")
        }
    }
    
    // 公共方法，用于获取是否激活书城功能
    public func isBookStoreActivated() -> Bool {
        let activated = config?.features.activateBookStore ?? true
        print("获取书城激活状态: \(activated)")
        return activated
    }
    
    // 公共方法，用于更新是否激活书城功能
    public func updateBookStoreActivation(_ activate: Bool) {
        guard var currentConfig = config else {
            print("无法更新配置，配置未加载")
            return
        }
        
        print("更新书城激活状态: \(activate)")
        
        // 创建新的配置对象，因为结构体是值类型
        let newConfig = AppConfig(
            status: currentConfig.status,
            version: currentConfig.version,
            features: AppConfig.Features(activateBookStore: activate),
            settings: currentConfig.settings
        )
        
        // 更新内存中的配置
        self.config = newConfig
        
        // 保存到文件
        saveConfigToDocuments(newConfig)
    }
    
    // 获取超时设置
    public func getTimeout() -> Int {
        let timeout = config?.settings.timeout ?? 30
        print("获取超时设置: \(timeout)")
        return timeout
    }
    
    // 获取重试次数
    public func getRetryCount() -> Int {
        let retryCount = config?.settings.retryCount ?? 3
        print("获取重试次数: \(retryCount)")
        return retryCount
    }
    
    // 强制刷新配置
    public func forceRefreshConfig() async {
        print("\n===== 开始强制刷新配置 =====")
        if let remoteConfig = await loadConfigFromRemote() {
            self.config = remoteConfig
            print("强制刷新配置成功")
            printConfigDetails(remoteConfig, source: "强制刷新的远程")
            
            // 保存到文档目录
            saveConfigToDocuments(remoteConfig)
            
            // 更新最后获取时间
            updateLastFetchTime()
            
            // 通知UI更新
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
            }
        } else {
            print("强制刷新配置失败")
        }
    }
}

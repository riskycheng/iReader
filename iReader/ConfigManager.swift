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
        #if DEBUG
        print("加载应用配置...")
        #endif
        
        // 首先尝试从远程URL加载配置文件
        if shouldFetchRemoteConfig() {
            #if DEBUG
            print("正在获取远程配置...")
            #endif
            
            Task {
                if let remoteConfig = await loadConfigFromRemote() {
                    self.config = remoteConfig
                    #if DEBUG
                    print("远程配置加载成功 [书城激活: \(remoteConfig.features.activateBookStore)]")
                    #endif
                    
                    // 保存到文档目录
                    saveConfigToDocuments(remoteConfig)
                    
                    // 更新最后获取时间
                    updateLastFetchTime()
                    
                    // 通知UI更新
                    NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
                    return
                } else {
                    #if DEBUG
                    print("远程配置加载失败，使用本地配置")
                    #endif
                    fallbackToLocalConfig()
                }
            }
        } else {
            #if DEBUG
            print("使用本地配置")
            #endif
            fallbackToLocalConfig()
        }
    }
    
    private func fallbackToLocalConfig() {
        // 尝试从文档目录加载配置文件
        if let documentsConfig = loadConfigFromDocuments() {
            self.config = documentsConfig
            #if DEBUG
            print("从文档目录加载配置 [书城激活: \(documentsConfig.features.activateBookStore)]")
            #endif
            return
        }
        
        // 如果文档目录没有配置文件，则从应用包中加载默认配置
        if let bundleConfig = loadConfigFromBundle() {
            self.config = bundleConfig
            #if DEBUG
            print("从应用包加载配置 [书城激活: \(bundleConfig.features.activateBookStore)]")
            #endif
            
            // 将默认配置复制到文档目录
            saveConfigToDocuments(bundleConfig)
            return
        }
        
        // 如果都没有找到配置文件，则创建默认配置
        let defaultConfig = createDefaultConfig()
        self.config = defaultConfig
        #if DEBUG
        print("创建默认配置 [书城激活: \(defaultConfig.features.activateBookStore)]")
        #endif
        
        // 保存默认配置到文档目录
        saveConfigToDocuments(defaultConfig)
    }
    
    private func shouldFetchRemoteConfig() -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: lastFetchTimeKey)
        let currentTime = Date().timeIntervalSince1970
        let hoursSinceLastFetch = (currentTime - lastFetchTime) / 3600
        
        return lastFetchTime == 0 || hoursSinceLastFetch >= fetchIntervalInHours
    }
    
    private func updateLastFetchTime() {
        let currentTime = Date().timeIntervalSince1970
        UserDefaults.standard.set(currentTime, forKey: lastFetchTimeKey)
    }
    
    private func loadConfigFromRemote() async -> AppConfig? {
        #if DEBUG
        print("正在请求远程配置...")
        #endif
        
        guard let url = URL(string: remoteConfigURL) else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            
            #if DEBUG
            print("远程配置解析成功 [状态: \(config.status), 版本: \(config.version)]")
            #endif
            
            return config
        } catch {
            #if DEBUG
            print("远程配置加载失败: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    private func loadConfigFromDocuments() -> AppConfig? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(configFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            return config
        } catch {
            #if DEBUG
            print("从文档目录加载配置失败: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    private func loadConfigFromBundle() -> AppConfig? {
        guard let fileURL = Bundle.main.url(forResource: "app_config", withExtension: "json") else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            return config
        } catch {
            #if DEBUG
            print("从应用包加载配置失败: \(error.localizedDescription)")
            #endif
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
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(configFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: fileURL)
        } catch {
            #if DEBUG
            print("保存配置到文档目录失败: \(error.localizedDescription)")
            #endif
        }
    }
    
    // 公共方法，用于获取是否激活书城功能
    public func isBookStoreActivated() -> Bool {
        return config?.features.activateBookStore ?? true
    }
    
    // 公共方法，用于更新是否激活书城功能
    public func updateBookStoreActivation(_ activate: Bool) {
        guard var currentConfig = config else {
            return
        }
        
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
        return config?.settings.timeout ?? 30
    }
    
    // 获取重试次数
    public func getRetryCount() -> Int {
        return config?.settings.retryCount ?? 3
    }
    
    // 强制刷新配置
    public func forceRefreshConfig() async {
        #if DEBUG
        print("正在强制刷新配置...")
        #endif
        
        if let remoteConfig = await loadConfigFromRemote() {
            let oldActivation = self.config?.features.activateBookStore
            self.config = remoteConfig
            
            #if DEBUG
            if let oldActivation = oldActivation {
                print("配置已更新 [书城激活: \(oldActivation) -> \(remoteConfig.features.activateBookStore)]")
            } else {
                print("配置已更新 [书城激活: \(remoteConfig.features.activateBookStore)]")
            }
            #endif
            
            // 保存到文档目录
            saveConfigToDocuments(remoteConfig)
            
            // 更新最后获取时间
            updateLastFetchTime()
            
            // 通知UI更新
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
            }
        } else {
            #if DEBUG
            print("强制刷新配置失败")
            #endif
        }
    }
}

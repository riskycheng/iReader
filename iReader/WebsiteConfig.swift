import Foundation

/// 网站配置类，集中管理所有与网站相关的URL和路径
struct WebsiteConfig {
    /// 当前网站的基础域名
    static let baseDomain = "www.qu08.cc"
    
    /// 完整的基础URL，包含协议
    static let baseURL = "https://\(baseDomain)"
    
    /// 章节内容的路径前缀
    static let chapterPathPrefix = "/read"
    
    /// 书籍详情的路径前缀
    static let bookPathPrefix = "/read"
    
    /// 搜索路径
    static let searchPath = "/s"
    
    /// 排行榜路径
    static let rankingPath = "/top"
    
    /// 构建完整的章节URL
    static func buildChapterURL(path: String) -> String {
        // 移除可能存在的旧路径前缀
        var cleanPath = path
        if cleanPath.hasPrefix("/books") {
            cleanPath = cleanPath.replacingOccurrences(of: "/books", with: "")
        }
        
        // 确保路径以/开头
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        return "\(baseURL)\(chapterPathPrefix)\(cleanPath)"
    }
    
    /// 更新URL，确保使用最新的域名和路径
    static func updateURL(_ urlString: String) -> String {
        var updatedURL = urlString
        
        // 替换旧路径前缀
        if updatedURL.contains("/books/") {
            updatedURL = updatedURL.replacingOccurrences(of: "/books/", with: "\(chapterPathPrefix)/")
        }
        
        // 确保使用最新的域名
        if !updatedURL.contains(baseDomain) {
            // 提取路径部分
            if let url = URL(string: updatedURL),
               let host = url.host,
               let pathStart = updatedURL.range(of: host)?.upperBound {
                let path = String(updatedURL[pathStart...])
                updatedURL = "\(baseURL)\(path)"
            }
        }
        
        return updatedURL
    }
    
    /// 构建完整的书籍详情URL
    static func buildBookURL(path: String) -> String {
        // 移除可能存在的旧路径前缀
        var cleanPath = path
        if cleanPath.hasPrefix("/books") {
            cleanPath = cleanPath.replacingOccurrences(of: "/books", with: "")
        }
        
        // 确保路径以/开头
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        return "\(baseURL)\(bookPathPrefix)\(cleanPath)"
    }
    
    /// 构建搜索URL
    static func buildSearchURL(query: String) -> String {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return baseURL
        }
        return "\(baseURL)\(searchPath)?q=\(encodedQuery)"
    }
    
    /// 构建排行榜URL
    static func buildRankingURL() -> String {
        return "\(baseURL)\(rankingPath)/"
    }
} 
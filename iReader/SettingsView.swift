import SwiftUI
import Foundation

// 在文件顶部添加一个私有的扩展来定义共享的样式
private extension Font {
    static let selectorTitle = Font.body
    static let selectorValue = Font.system(.body, design: .rounded)
    static let selectorCaption = Font.caption
    static let optionText = Font.system(.subheadline, design: .rounded)
}

struct SettingsView: View {
    @AppStorage("autoPreload") private var autoPreload = true
    @AppStorage("preloadChaptersCount") private var preloadChaptersCount = 5
    @AppStorage("shouldShowGestureTutorial") private var shouldShowGestureTutorial = true
    @AppStorage("autoCheckUpdate") private var autoCheckUpdate = true
    @AppStorage("checkUpdateInterval") private var checkUpdateInterval = 30 // 默认30分钟检查一次
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingAboutUs = false
    @State private var showPreloadSettings = false
    @State private var isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
    @State private var showRestartAlert = false
    @State private var showingRefreshAlert = false
    @State private var configStatusText = ""
    
    var body: some View {
        NavigationView {
            List {
                // 书城设置部分
                Section {
                    // 添加刷新远程配置的按钮
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("刷新远程配置")
                                .font(.body)
                            
                            if !configStatusText.isEmpty {
                                Text(configStatusText)
                                    .font(.caption)
                                    .foregroundColor(isBookStoreActivated ? .green : .secondary)
                            } else {
                                Text("从服务器获取最新配置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                #if DEBUG
                                print("开始刷新远程配置...")
                                #endif
                                
                                await ConfigManager.shared.forceRefreshConfig()
                                isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                                
                                // 更新状态文本
                                configStatusText = "当前书城状态：\(isBookStoreActivated ? "在线" : "本地")"
                                
                                #if DEBUG
                                print("远程配置刷新完成 [书城激活: \(isBookStoreActivated)]")
                                #endif
                                
                                // 在主线程上更新UI
                                await MainActor.run {
                                    showingRefreshAlert = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                Text("刷新")
                            }
                        }
                    }
                    
                    // 添加网络状态指示器
                    if ConfigManager.shared.hasNetworkError() {
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("网络连接问题")
                                    .font(.body)
                                
                                Text("无法连接到远程服务器，使用本地书城")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                ConfigManager.shared.resetNetworkErrorState()
                                Task {
                                    await ConfigManager.shared.forceRefreshConfig()
                                    isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                                    // 更新状态文本
                                    configStatusText = "当前书城状态：\(isBookStoreActivated ? "在线" : "本地")"
                                }
                            }) {
                                Text("重试")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("远程配置")
                }
                .alert("配置已刷新", isPresented: $showingRefreshAlert) {
                    Button("确定", role: .cancel) { }
                } message: {
                    Text("远程配置已成功刷新，书城状态：\(isBookStoreActivated ? "在线" : "本地")")
                }
                
                // 阅读设置部分
                Section {
                    // 预加载开关
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自动预加载")
                                .font(.body)
                            
                            Text("阅读时自动预加载后续章节")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoPreload)
                            .labelsHidden()
                    }
                    
                    // 预加载章节数量选择器
                    if autoPreload {
                        PreloadChapterSelector(
                            preloadChaptersCount: $preloadChaptersCount,
                            autoPreload: $autoPreload
                        )
                    }
                    
                    // 阅读手势教程设置保持不变
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("阅读手势教程")
                                .font(.body)
                            
                            Text("打开书籍时显示操作提示")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $shouldShowGestureTutorial)
                            .labelsHidden()
                    }
                    
                    // 自动检查更新开关
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自动检查更新")
                                .font(.body)
                            
                            Text("定时检查更新书架中书籍章节")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoCheckUpdate)
                            .labelsHidden()
                    }
                    
                    // 检查更新间隔选择器
                    if autoCheckUpdate {
                        UpdateIntervalSelector(
                            checkUpdateInterval: $checkUpdateInterval,
                            autoCheckUpdate: $autoCheckUpdate
                        )
                    }
                } header: {
                    Text("阅读设置")
                }
                
                // 历史记录部分
                Section {
                    NavigationLink(destination: ReadingHistoryView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("阅读记录")
                                    .font(.body)
                                
                                Text("查看最近阅读的书籍")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: BrowsingHistoryView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("浏览记录")
                                    .font(.body)
                                
                                Text("查看最近浏览的书籍")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("历史记录")
                }
                
                // 关于分
                Section {
                    Button(action: { showingAboutUs = true }) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("关于我们")
                                    .font(.body)
                                
                                Text("版本信息与法律声明")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .listStyle(InsetGroupedListStyle())
            .sheet(isPresented: $showingAboutUs) {
                ModernAboutUsView()
            }
            .alert(isPresented: $showRestartAlert) {
                Alert(
                    title: Text("设置已更改"),
                    message: Text("书城功能设置已更改，请重启应用以使更改生效。"),
                    dismissButton: .default(Text("知道了"))
                )
            }
            .onAppear {
                // 每次视图出现时检查配置
                isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                // 设置初始状态文本
                configStatusText = "当前书城状态：\(isBookStoreActivated ? "在线" : "本地")"
            }
        }
    }
}

// 现代化的关于我们视图
struct ModernAboutUsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingShareAlert = false
    
    // 方案1：直接获取应用图标
    private var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
    
    // 方案2：从应用程序获取图标
    private var applicationIcon: UIImage? {
        return UIApplication.shared.icon
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题区域
                HStack {
                    Text("关于我们")
                        .font(.headline)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .imageScale(.large)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                // 应用信息卡片
                VStack(spacing: 16) {
                    // 使用方案1或方案2获取的图标
                    if let icon = appIcon ?? UIApplication.shared.icon {
                        Image(uiImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                    }
                    
                    Text(Bundle.main.displayName ?? "笔趣爱读")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Text("版本 1.0.5(105)")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                
                // 列表内容
                List {
                    // 隐私和协议部分
                    Section {
                        NavigationLink(destination: PrivacyPolicyView()) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("隐私政策")
                            }
                        }
                        
                        NavigationLink(destination: TermsOfServiceView()) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                Text("服务协议")
                            }
                        }
                    }
                    
                    // 联系我们部分
                    Section {
                        // 反馈按钮
                        Button(action: {
                            let phoneNumber = "17602171768"
                            if let url = URL(string: "sms:\(phoneNumber)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "message.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text("反馈")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .imageScale(.small)
                            }
                        }
                        
                        // 邮箱按钮
                        Button(action: {
                            showingShareAlert = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("邮箱")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .imageScale(.small)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationBarHidden(true) // 隐藏导航栏
            .overlay(
                Group {
                    if showingShareAlert {
                        CustomShareAlert(
                            isPresented: $showingShareAlert,
                            onConfirm: {
                                if let url = URL(string: "mailto:riskycheng@gmail.com") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                    }
                }
            )
        }
    }
}

// 添加 UIApplication 扩展来获取应用图标
extension UIApplication {
    var icon: UIImage? {
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

// 修改分享对话框为邮箱对话框
struct CustomShareAlert: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 20) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .padding(.top, 25)
                
                Text("联系邮箱")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                VStack(spacing: 8) {
                    Text("riskycheng@gmail.com")
                        .font(.system(size: 17, weight: .medium))
                }
                .padding(.horizontal)
                
                Text("如有任何问题，欢迎联系我们")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 15) {
                    Button {
                        withAnimation {
                            isPresented = false
                        }
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    Button {
                        withAnimation {
                            isPresented = false
                            onConfirm()
                        }
                    } label: {
                        Text("确认")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 25)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSection: String?
    @State private var showingShareAlert = false
    
    private let sections = [
        PolicySection(
            id: "collection",
            icon: "square.and.pencil.circle.fill",
            color: .blue,
            title: "信息收集与使用",
            content: [
                "阅读进度记录",
                "个性化偏好设置",
                "书籍收藏管理",
                "阅读统计数据"
            ]
        ),
        PolicySection(
            id: "storage",
            icon: "externaldrive.fill",
            color: .purple,
            title: "数据存储",
            content: [
                "本地数据存储",
                "无云端数据传输",
                "无第三方数据共享",
                "定期数据清理机制"
            ]
        ),
        PolicySection(
            id: "network",
            icon: "network",
            color: .green,
            title: "网络访问",
            content: [
                "内容源获取",
                "资源缓存机制",
                "流量优化策略",
                "网络安全保护"
            ]
        ),
        PolicySection(
            id: "privacy",
            icon: "lock.shield.fill",
            color: .orange,
            title: "用户隐私保护",
            content: [
                "无个人信息采集",
                "无用户行为追踪",
                "无第三方SDK接入",
                "本地数据加密存储"
            ]
        ),
        PolicySection(
            id: "permissions",
            icon: "checkmark.shield.fill",
            color: .blue,
            title: "系统权限",
            content: [
                "网络访问权限",
                "本地存储权限",
                "知权限(可选)",
                "后台更新(可选)"
            ]
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部标题区域
                HeaderView()
                
                // 最后更新时
                Text("最后更新日期：2024年12月20日")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                // 政策章节列表
                LazyVStack(spacing: 16) {
                    ForEach(sections) { section in
                        PolicySectionCard(
                            section: section,
                            isExpanded: selectedSection == section.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedSection = selectedSection == section.id ? nil : section.id
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 底部联系方式
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    Text("如有任何问题，请联系我们")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingShareAlert = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("联系我们")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 20)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                    Text("返回")
                }
                .foregroundColor(.accentColor)
            }
        )
        .navigationBarTitle("隐私政策", displayMode: .inline)
        .background(backgroundGradient)
        .overlay(
            Group {
                if showingShareAlert {
                    CustomShareAlert(
                        isPresented: $showingShareAlert,
                        onConfirm: {
                            if let url = URL(string: "mailto:riskycheng@gmail.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
            }
        )
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(colorScheme == .dark ? .systemGray6 : .systemBackground),
                Color(colorScheme == .dark ? .systemGray5 : .systemGray6)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// 服务协议视图
struct TermsOfServiceView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSection: String?
    @State private var showingShareAlert = false
    
    private let sections = [
        TermsSection(
            id: "service",
            icon: "doc.text.fill",
            color: .blue,
            title: "服务说明",
            content: """
            笔趣爱读是一款专注于提供优质阅读体验的应用程序。我们通过先进的内容聚合技术，为用户提供来自互联网的公开阅读资源。
            """
        ),
        TermsSection(
            id: "disclaimer",
            icon: "exclamationmark.shield.fill",
            color: .red,
            title: "免责声明",
            content: """
            • 内容来源：所有内容均来自互联网公开资源
            • 内容核：我们会及时处理任何版权或合规问题
            • 使用限制：仅供个人学习参考，禁止用于商业用途
            • 合规要求：用户需遵守相关法律法规
            """
        ),
        TermsSection(
            id: "obligations",
            icon: "person.text.rectangle.fill",
            color: .green,
            title: "用户义务",
            content: """
            • 遵守法律法规和社会公德
            • 尊重知识产权，合理使用内容
            • 不得从事任何违法或未授权行为
            • 及时报告发现的问题内容
            """
        ),
        TermsSection(
            id: "content",
            icon: "doc.richtext.fill",
            color: .orange,
            title: "内容处理",
            content: """
            如发现内容存在以下问题，我们将及时处理：
            • 侵犯知识产权
            • 违反法律法规
            • 违反社会公德
            • 其他争议内容
            """
        ),
        TermsSection(
            id: "changes",
            icon: "arrow.triangle.2.circlepath",
            color: .purple,
            title: "服务变更",
            content: """
            我们保留对服务进行以下调整的权利：
            • 功能优化与更新
            • 内容源更新维护
            • 使用规则调整
            • 服务条款更新
            """
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部标题区域
                HeaderView()
                
                // 最后更新时间
                Text("最后更新日期：2024年12月20日")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                // 协议章节列表
                LazyVStack(spacing: 16) {
                    ForEach(sections) { section in
                        TermsSectionCard(
                            section: section,
                            isExpanded: selectedSection == section.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedSection = selectedSection == section.id ? nil : section.id
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 底部联系方式
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    Text("如有任何问题，请联系我们")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingShareAlert = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("联系我们")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 20)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                    Text("返回")
                }
                .foregroundColor(.accentColor)
            }
        )
        .navigationBarTitle("服务协议", displayMode: .inline)
        .overlay(
            Group {
                if showingShareAlert {
                    CustomShareAlert(
                        isPresented: $showingShareAlert,
                        onConfirm: {
                            if let url = URL(string: "mailto:riskycheng@gmail.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
            }
        )
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(colorScheme == .dark ? .systemGray6 : .systemBackground),
                Color(colorScheme == .dark ? .systemGray5 : .systemGray6)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// 支持结构
struct PolicySection: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let content: [String]
}

struct TermsSection: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let content: String
}

// 组件视图
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            // 使用应用图标
            if let image = UIImage(named: "AppIcon") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
            }
            
            Text(Bundle.main.displayName ?? "笔趣爱读")
                .font(.title2.weight(.bold))
            
            Text("请仔细阅读以下内容")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
}

struct PolicySectionCard: View {
    let section: PolicySection
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(section.color)
                
                Text(section.title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundColor(.secondary)
            }
            
            // 展开的内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.content, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(section.color)
                                .imageScale(.small)
                            Text(item)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.leading, 4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

struct TermsSectionCard: View {
    let section: TermsSection
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(section.color)
                
                Text(section.title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundColor(.secondary)
            }
            
            // 展开的内容
            if isExpanded {
                Text(section.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// 首先创建一个用于处理分享的协调器
class ShareCoordinator: NSObject {
    static let shared = ShareCoordinator()
    
    func share(from view: UIView) {
        let text = "笔趣爱读 - 您的掌上阅读伴侣"
        
        // 创建分享项
        var itemsToShare: [Any] = [text]
        
        // 创建分享视图控制器
        let activityVC = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        // 获取当前最顶层的视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController?.presentedViewController ?? window.rootViewController {
            
            // 在 iPad 上需要设置 popoverPresentationController
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            
            // 确保在主线程上展示
            DispatchQueue.main.async {
                rootViewController.dismiss(animated: true) {
                    rootViewController.present(activityVC, animated: true)
                }
            }
        }
    }
}

// 修改 ContactSection 中的分享按钮实现
struct ContactSection: View {
    @State private var shareAnchor: CGRect = .zero
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal)
            
            Text("如有任何问题，请联系我们")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                // 反馈按钮 - 跳转到短信
                Button(action: {
                    let phoneNumber = "17602171768"
                    if let url = URL(string: "sms:\(phoneNumber)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("反馈", systemImage: "message.fill")
                }
                
                // 分享按钮 - 使用新的分享方式
                Button(action: {
                    // 获取按钮的 UIView
                    guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
                          let hostView = window.rootViewController?.view else { return }
                    
                    ShareCoordinator.shared.share(from: hostView)
                }) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.top)
    }
}

struct ReadingHistoryView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedBook: Book?
    @State private var isShowingBookReader = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            ForEach(viewModel.readingHistory) { record in
                ReadingHistoryItemView(record: record)
                    .onTapGesture {
                        selectedBook = record.book
                    }
            }
            .onDelete(perform: deleteReadingHistory)
        }
        .navigationTitle("阅读记录")
        .navigationBarItems(trailing: Button(action: {
            showingDeleteAlert = true
        }) {
            Text("清空")
                .foregroundColor(.red)
        })
        .onAppear {
            viewModel.refreshReadingHistory()
        }
        .sheet(item: $selectedBook) { book in
            if let progress = libraryManager.getReadingProgress(for: book.id) {
                BookReadingView(book: book, isPresented: $isShowingBookReader, startingChapter: progress.chapterIndex)
            } else {
                BookInfoView(book: book)
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("确认清空"),
                message: Text("确定要清空所有阅读记录吗？此操作不可恢复。"),
                primaryButton: .destructive(Text("清空")) {
                    viewModel.clearAllReadingHistory()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private func deleteReadingHistory(at offsets: IndexSet) {
        viewModel.deleteReadingHistory(at: offsets)
    }
}

struct ReadingHistoryItemView: View {
    let record: ReadingRecord
    
    var body: some View {
        HStack(spacing: 15) {
            // 封面图 - 使用缓存
            if let cachedImage = ImageCache.shared.image(for: record.book.coverURL) {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                AsyncImage(url: URL(string: record.book.coverURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // 文字信息
            VStack(alignment: .leading, spacing: 8) {
                Text(record.book.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text(record.book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Text("上次阅读: \(record.lastChapter)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text(record.lastReadTime)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 10)
    }
}

struct BrowsingHistoryView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingClearConfirmation = false
    
    var body: some View {
        List {
            if viewModel.browsingHistory.isEmpty {
                Text("暂无浏览记录")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.browsingHistory) { record in
                    NavigationLink(destination: BookInfoView(book: record.book)) {
                        BrowsingHistoryItemView(record: record)
                    }
                }
                .onDelete(perform: viewModel.deleteBrowsingHistory)
            }
        }
        .navigationTitle("浏览记录")
        .navigationBarItems(trailing: Button(action: {
            showingClearConfirmation = true
        }) {
            Text("清空")
                .foregroundColor(.red)
        })
        .alert(isPresented: $showingClearConfirmation) {
            Alert(
                title: Text("确认清空"),
                message: Text("确定要清空所有浏览记录吗？此操作不可恢复。"),
                primaryButton: .destructive(Text("清空")) {
                    viewModel.clearAllBrowsingHistory()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .onAppear {
            viewModel.refreshBrowsingHistory()
        }
    }
}

struct BrowsingHistoryItemView: View {
    let record: BrowsingRecord
    
    var body: some View {
        HStack(spacing: 15) {
            // 封面图 - 使用缓存
            if let cachedImage = ImageCache.shared.image(for: record.book.coverURL) {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                AsyncImage(url: URL(string: record.book.coverURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // 文字信息
            VStack(alignment: .leading, spacing: 8) {
                Text(record.book.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text(record.book.author)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Text(record.browseTime)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}

class SettingsViewModel: ObservableObject {
    @Published var readingHistory: [ReadingRecord] = []
    @Published var browsingHistory: [BrowsingRecord] = []
    
    init() {
        loadReadingHistory()
        loadBrowsingHistory()
    }
    
    func loadReadingHistory() {
        var history = UserDefaults.standard.readingHistory()
        
        // 使用 Dictionary 的 grouping 特性来实现去重
        // 按照 book.id 分组，只保留每组中最新的记录
        let uniqueHistory = Dictionary(grouping: history) { $0.book.id }
            .values
            .compactMap { records -> ReadingRecord? in
                // 对每组记录按时间排序，取最新的一条
                records.sorted { record1, record2 in
                    // 使用日期，确保最新记录排在前面
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                    let date1 = dateFormatter.date(from: record1.lastReadTime) ?? Date.distantPast
                    let date2 = dateFormatter.date(from: record2.lastReadTime) ?? Date.distantPast
                    return date1 > date2
                }.first
            }
            .sorted { record1, record2 in
                // 对去重后的记录按时间倒序排序
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                let date1 = dateFormatter.date(from: record1.lastReadTime) ?? Date.distantPast
                let date2 = dateFormatter.date(from: record2.lastReadTime) ?? Date.distantPast
                return date1 > date2
            }
        
        readingHistory = uniqueHistory
    }
    
    func loadBrowsingHistory() {
        var history = UserDefaults.standard.browsingHistory()
        
        // 对浏览记录执行相同的去重逻辑
        let uniqueHistory = Dictionary(grouping: history) { $0.book.id }
            .values
            .compactMap { records -> BrowsingRecord? in
                records.sorted { record1, record2 in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                    let date1 = dateFormatter.date(from: record1.browseTime) ?? Date.distantPast
                    let date2 = dateFormatter.date(from: record2.browseTime) ?? Date.distantPast
                    return date1 > date2
                }.first
            }
            .sorted { record1, record2 in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
                let date1 = dateFormatter.date(from: record1.browseTime) ?? Date.distantPast
                let date2 = dateFormatter.date(from: record2.browseTime) ?? Date.distantPast
                return date1 > date2
            }
        
        browsingHistory = uniqueHistory
    }
    
    func deleteReadingHistory(at offsets: IndexSet) {
        readingHistory.remove(atOffsets: offsets)
        UserDefaults.standard.saveReadingHistory(readingHistory)
    }
    
    func deleteBrowsingHistory(at offsets: IndexSet) {
        browsingHistory.remove(atOffsets: offsets)
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
    }
    
    func addBrowsingRecord(_ book: Book) {
        let currentTime = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
        
        let record = BrowsingRecord(
            id: UUID(),
            book: book,
            browseTime: dateFormatter.string(from: currentTime)
        )
        
        // 获取现有的浏览历史
        var browsingHistory = UserDefaults.standard.browsingHistory()
        
        // 移除所有该书的历史记录
        browsingHistory.removeAll { $0.book.id == book.id }
        
        // 加记录到列表开头
        browsingHistory.insert(record, at: 0)
        
        // 限制历史记录数量
        if browsingHistory.count > 50 {
            browsingHistory = Array(browsingHistory.prefix(50))
        }
        
        // 保存更新后的浏览历史
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
        
        // 更新发布的属性
        self.browsingHistory = browsingHistory
        
        // 强制刷新视图
        self.objectWillChange.send()
    }
    
    func refreshBrowsingHistory() {
        browsingHistory = UserDefaults.standard.browsingHistory()
        #if DEBUG
        print("刷新浏览历史记录，当前数量: \(browsingHistory.count)")
        #endif
    }
    
    func refreshReadingHistory() {
        readingHistory = UserDefaults.standard.readingHistory()
        #if DEBUG
        print("刷新阅读历史记录，当前数量: \(readingHistory.count)")
        #endif
    }
    
    func clearAllReadingHistory() {
        readingHistory.removeAll()
        UserDefaults.standard.saveReadingHistory(readingHistory)
    }
    
    func clearAllBrowsingHistory() {
        browsingHistory.removeAll()
        UserDefaults.standard.saveBrowsingHistory(browsingHistory)
    }
    
    func addReadingRecord(_ book: Book, lastChapter: String) {
        let currentTime = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy 'at' HH:mm"
        
        let record = ReadingRecord(
            id: UUID(),
            book: book,
            lastChapter: lastChapter,
            lastReadTime: dateFormatter.string(from: currentTime)
        )
        
        // 获取现有的阅读历史
        var readingHistory = UserDefaults.standard.readingHistory()
        
        // 移除所有该书的历史记录
        readingHistory.removeAll { $0.book.id == book.id }
        
        // 加新记录到列表开头
        readingHistory.insert(record, at: 0)
        
        // 限制历史记录数量
        if readingHistory.count > 50 {
            readingHistory = Array(readingHistory.prefix(50))
        }
        
        // 保存更新后的阅读历史
        UserDefaults.standard.saveReadingHistory(readingHistory)
        
        // 更新发布的属性
        self.readingHistory = readingHistory
        
        // 强制刷新视图
        self.objectWillChange.send()
    }
}

struct ReadingRecord: Codable, Identifiable {
    let id: UUID
    let book: Book
    let lastChapter: String
    let lastReadTime: String
}

struct BrowsingRecord: Codable, Identifiable {
    let id: UUID
    let book: Book
    let browseTime: String
}

struct AboutUsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(white: 0.95), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // 图标部分
                    VStack(spacing: 8) {
                        if let image = UIImage(named: "AppLogo") {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(16)
                        } else {
                            Image(systemName: "book.closed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.blue)
                        }
                        
                        Text(Bundle.main.displayName ?? "妙笔阅读")
                            .font(.system(size: 22, weight: .medium))
                        
                        Text("版本：v \(Bundle.main.appVersion)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // 协议部分
                    VStack(spacing: 0) {
                        NavigationLink(destination: PrivacyPolicyView()) {
                            HStack {
                                Text("隐私协议")
                                    .foregroundColor(.primary)
                                    .padding(.leading, 16)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                            .padding(.vertical, 16)
                        }
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        NavigationLink(destination: TermsOfServiceView()) {
                            HStack {
                                Text("服务协议")
                                    .foregroundColor(.primary)
                                    .padding(.leading, 16)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                            .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitle("关于我们", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

extension UserDefaults {
    func readingHistory() -> [ReadingRecord] {
        guard let data = data(forKey: "readingHistory") else { return [] }
        return (try? JSONDecoder().decode([ReadingRecord].self, from: data)) ?? []
    }
    
    func saveReadingHistory(_ history: [ReadingRecord]) {
        let data = try? JSONEncoder().encode(history)
        set(data, forKey: "readingHistory")
    }
    
    func browsingHistory() -> [BrowsingRecord] {
        guard let data = data(forKey: "browsingHistory") else { return [] }
        return (try? JSONDecoder().decode([BrowsingRecord].self, from: data)) ?? []
    }
    
    func saveBrowsingHistory(_ history: [BrowsingRecord]) {
        let data = try? JSONEncoder().encode(history)
        set(data, forKey: "browsingHistory")
    }
}

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String 
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var appVersion: String {
        return "\(object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")(\(object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))"
    }
}

struct PreloadChapterSelector: View {
    @Binding var preloadChaptersCount: Int
    @Binding var autoPreload: Bool
    @State private var isExpanded = false
    
    private let presetValues = [2, 4, 6, 8, 10] // 章节数选项
    
    var body: some View {
        VStack(spacing: 0) {
            // 主标题区域
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("预加载章节")
                                .font(.selectorTitle)
                            Text("\(preloadChaptersCount)章")
                                .font(.selectorValue)
                                .foregroundColor(.blue)
                        }
                        
                        Text("点击配置预加载数量")
                            .font(.selectorCaption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开的选择器
            if isExpanded {
                VStack(spacing: 16) {
                    // 选项列表 - 移除 ScrollView，使用固定布局
                    HStack(spacing: 8) {
                        ForEach(presetValues, id: \.self) { value in
                            Button(action: {
                                withAnimation {
                                    preloadChaptersCount = value
                                }
                            }) {
                                Text("\(value)章")
                                    .font(.optionText)
                                    .foregroundColor(preloadChaptersCount == value ? .blue : .gray)
                                    .frame(maxWidth: .infinity) // 确保按钮平均分配宽度
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(preloadChaptersCount == value ? 
                                                 Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(preloadChaptersCount == value ? 
                                                   Color.blue.opacity(0.5) : Color.clear,
                                                   lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    
                    // 警告提示
                    if preloadChaptersCount > 6 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text("预加载过多章节可能会影响性能")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
    }
}

struct UpdateIntervalSelector: View {
    @Binding var checkUpdateInterval: Int
    @Binding var autoCheckUpdate: Bool
    @State private var isExpanded = false
    
    private let intervals = [15, 30, 60, 120] // 分钟
    
    var body: some View {
        VStack(spacing: 0) {
            // 主标题区域
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("检查间隔")
                                .font(.selectorTitle)
                            Text("\(checkUpdateInterval)分钟")
                                .font(.selectorValue)
                                .foregroundColor(.blue)
                        }
                        
                        Text("点击设置检查间隔")
                            .font(.selectorCaption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展开的选择器
            if isExpanded {
                VStack(spacing: 16) {
                    // 选项列表
                    HStack(spacing: 8) {
                        ForEach(intervals, id: \.self) { interval in
                            Button(action: {
                                withAnimation {
                                    checkUpdateInterval = interval
                                }
                            }) {
                                Text("\(interval)分钟")
                                    .font(.optionText)
                                    .foregroundColor(checkUpdateInterval == interval ? .blue : .gray)
                                    .frame(maxWidth: .infinity) // 确保按钮平均分配宽度
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(checkUpdateInterval == interval ? 
                                                 Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(checkUpdateInterval == interval ? 
                                                   Color.blue.opacity(0.5) : Color.clear,
                                                   lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    
                    // 警告提示
                    if checkUpdateInterval < 30 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text("频繁检查可能会增加耗电")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
    }
}

import SwiftUI

struct TabViewSelectionKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var tabViewSelection: Int {
        get { self[TabViewSelectionKey.self] }
        set { self[TabViewSelectionKey.self] = newValue }
    }
}

struct MainAppView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var selectedTab = 0
    @State private var selectedBook: Book?
    @State private var isShowingBookReader = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                BookLibrariesView(
                    selectedBook: $selectedBook, 
                    isShowingBookReader: $isShowingBookReader,
                    selectedTab: $selectedTab
                )
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("书架")
                }
                .tag(0)
                
                Group {
                    if isBookStoreActivated {
                        BookStoreView()
                    } else {
                        LocalBookStoreView()
                    }
                }
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text(isBookStoreActivated ? "书城" : "本地")
                }
                .tag(1)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "person")
                        Text("我")
                    }
                    .tag(2)
            }
            .environmentObject(libraryManager)
            .environmentObject(settingsViewModel)
            .environment(\.tabViewSelection, selectedTab)
            .onChange(of: selectedBook) { book in
                #if DEBUG
                if let book = book {
                    print("选择书籍: \(book.title)")
                }
                #endif
                if let book = book {
                    settingsViewModel.addBrowsingRecord(book)
                }
            }
            .fullScreenCover(isPresented: $isShowingBookReader, content: {
                if let book = selectedBook {
                    BookReadingView(
                        book: book,
                        isPresented: $isShowingBookReader,
                        shouldSaveProgress: true
                    )
                } else {
                    Text("No book selected")
                }
            })
            .onAppear {
                // 每次视图出现时检查配置
                isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                
                #if DEBUG
                print("MainAppView - 当前书城激活状态: \(isBookStoreActivated)")
                #endif
                
                // 如果当前书城状态为false，则尝试获取远程配置
                if !isBookStoreActivated {
                    #if DEBUG
                    print("MainAppView - 当前书城状态为false，尝试获取远程配置...")
                    #endif
                    
                    Task {
                        await ConfigManager.shared.forceRefreshConfig()
                        await MainActor.run {
                            isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                            #if DEBUG
                            print("MainAppView - 配置刷新后的书城激活状态: \(isBookStoreActivated)")
                            print("MainAppView - 网络错误状态: \(ConfigManager.shared.hasNetworkError())")
                            #endif
                        }
                    }
                } else {
                    #if DEBUG
                    print("MainAppView - 当前书城状态为true，不需要获取远程配置")
                    #endif
                }
                
                // 添加配置更新通知的观察者
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ConfigUpdated"),
                    object: nil,
                    queue: .main
                ) { _ in
                    #if DEBUG
                    print("配置已更新")
                    #endif
                    isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                    #if DEBUG
                    print("MainAppView - 通知更新后的书城激活状态: \(isBookStoreActivated)")
                    print("MainAppView - 网络错误状态: \(ConfigManager.shared.hasNetworkError())")
                    #endif
                }
            }
            
            if !hasSeenOnboarding {
                OnboardingView(isShowingOnboarding: $hasSeenOnboarding)
                    .transition(.opacity)
            }
        }
    }
}

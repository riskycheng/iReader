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
                print("Selected book changed: \(book?.title ?? "nil")")
                if let book = book {
                    settingsViewModel.addBrowsingRecord(book)
                }
            }
            .onChange(of: isShowingBookReader) { isShowing in
                print("isShowingBookReader changed: \(isShowing)")
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
                print("\n===== MainAppView 出现 =====")
                // 每次视图出现时检查配置
                isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                print("当前书城激活状态: \(isBookStoreActivated)")
                
                // 立即尝试获取远程配置
                Task {
                    print("开始强制刷新远程配置...")
                    await ConfigManager.shared.forceRefreshConfig()
                    await MainActor.run {
                        isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                        print("刷新后的书城激活状态: \(isBookStoreActivated)")
                    }
                }
                
                // 添加配置更新通知的观察者
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ConfigUpdated"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("收到配置更新通知")
                    isBookStoreActivated = ConfigManager.shared.isBookStoreActivated()
                    print("更新后的书城激活状态: \(isBookStoreActivated)")
                }
            }
            
            if !hasSeenOnboarding {
                OnboardingView(isShowingOnboarding: $hasSeenOnboarding)
                    .transition(.opacity)
            }
        }
    }
}

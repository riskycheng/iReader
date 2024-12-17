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
                
                BookStoreView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("书城")
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
                    BookReadingView(book: book, isPresented: $isShowingBookReader)
                } else {
                    Text("No book selected")
                }
            })
            
            if !hasSeenOnboarding {
                OnboardingView(isShowingOnboarding: $hasSeenOnboarding)
                    .transition(.opacity)
            }
        }
    }
}

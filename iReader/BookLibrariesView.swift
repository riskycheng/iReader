import SwiftUI

struct BookLibrariesView: View {
    @StateObject private var viewModel = BookLibrariesViewModel()
    @EnvironmentObject private var libraryManager: LibraryManager
    @Binding var selectedBook: Book?
    @Binding var isShowingBookReader: Bool
    @State private var bookForInfo: Book?
    @State private var bookToRemove: Book?
    @State private var showingRemoveConfirmation = false
    @State private var isRefreshing = false
    
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    RefreshControl(coordinateSpace: .named("RefreshControl"), onRefresh: {
                        isRefreshing = true
                        Task {
                            await viewModel.refreshBooks()
                            isRefreshing = false
                        }
                    })
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 20) {
                        ForEach(viewModel.books) { book in
                            NavigationLink(destination: BookInfoView(book: book), tag: book, selection: $bookForInfo) {
                                BookCoverView(book: book)
                                    .contextMenu {
                                        Button(action: {
                                            bookForInfo = book
                                        }) {
                                            Label("Book Info", systemImage: "info.circle")
                                        }
                                        
                                        Button(action: {
                                            bookToRemove = book
                                            showingRemoveConfirmation = true
                                        }) {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                    .onTapGesture {
                                        selectedBook = book
                                        isShowingBookReader = true
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        AddBookButton()
                    }
                    .padding()
                }
                .coordinateSpace(name: "RefreshControl")
                
                if isRefreshing {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    loadingView
                        .transition(.opacity)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
            .navigationTitle("书架")
        }
        .onAppear {
            viewModel.setLibraryManager(libraryManager)
            if viewModel.books.isEmpty {
                viewModel.loadBooks()
            }
        }
        .confirmationDialog("Remove Book", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let book = bookToRemove {
                    viewModel.removeBook(book)
                }
            }
            Button("Cancel", role: .cancel) {
                bookToRemove = nil
            }
        } message: {
            Text("Are you sure you want to remove this book from your library? This action cannot be undone.")
        }
    }
    
    private var combinedBooks: [Book] {
        // Combine books from viewModel and libraryManager, removing duplicates
        let allBooks = viewModel.books + libraryManager.books
        return Array(Set(allBooks))
    }
    
    private var bookList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 20) {
                ForEach(viewModel.books) { book in
                    BookCoverView(book: book)
                        .onTapGesture {
                            selectedBook = book
                            isShowingBookReader = true
                        }
                }
                AddBookButton()
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshBooks()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(viewModel.loadingMessage)
                .font(.headline)
            Text("\(viewModel.loadedBooksCount)/\(viewModel.totalBooksCount) books loaded")
                .font(.subheadline)
            ProgressView(value: Double(viewModel.loadedBooksCount), total: Double(viewModel.totalBooksCount))
                .frame(width: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.refreshBooks()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}

struct RefreshControl: View {
    var coordinateSpace: CoordinateSpace
    var onRefresh: () -> Void
    @State private var isRefreshing = false
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let threshold: CGFloat = 50
            let y = geo.frame(in: coordinateSpace).minY
            let pullProgress = min(max(0, y / threshold), 1)
            
            ZStack(alignment: .center) {
                if isRefreshing {
                    ProgressView()
                } else {
                    ProgressView(value: pullProgress)
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .frame(width: geo.size.width, height: threshold)
            .opacity(pullProgress)
            .onChange(of: y) { newValue in
                progress = pullProgress
                if newValue > threshold && !isRefreshing {
                    isRefreshing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onRefresh()
                        isRefreshing = false
                    }
                }
            }
        }
        .frame(height: 50)
    }
}


struct AddBookButton: View {
    var body: some View {
        VStack {
            Image(systemName: "plus")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
            Text("添加书籍")
                .font(.caption)
        }
        .frame(width: 90, height: 170)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

struct BookLibrariesView_Previews: PreviewProvider {
    static var previews: some View {
        BookLibrariesView(
            selectedBook: .constant(nil),
            isShowingBookReader: .constant(false)
        )
    }
}

import SwiftUI

struct BookLibrariesView: View {
    @StateObject private var viewModel = BookLibrariesViewModel()
    @EnvironmentObject private var libraryManager: LibraryManager
    @Binding var selectedBook: Book?
    @Binding var isShowingBookReader: Bool
    @State private var bookForInfo: Book?
    @State private var bookToRemove: Book?
    @State private var showingRemoveConfirmation = false
    @State private var isPulling = false
    @State private var pullProgress: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    RefreshControl(
                        coordinateSpace: .named("RefreshControl"),
                        onRefresh: {
                            Task {
                                await viewModel.refreshBooksOnRelease()
                            }
                        },
                        isPulling: $isPulling,
                        pullProgress: $pullProgress
                    )
                    
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
                
                if viewModel.isLoading {
                                    ElegantLoadingView(
                                        message: viewModel.loadingMessage,
                                        progress: Double(viewModel.loadedBooksCount) / Double(viewModel.totalBooksCount),
                                        totalBooks: viewModel.totalBooksCount,
                                        currentBookName: viewModel.currentBookName
                                    )
                                }
                                
                
                if let error = viewModel.errorMessage {
                    ElegantErrorView(message: error)
                }
            }
            .navigationTitle("书架")
        }
        .onAppear {
            viewModel.setLibraryManager(libraryManager)
        }
        .confirmationDialog("Remove Book", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let book = bookToRemove {
                    viewModel.removeBook(book)
                    bookToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                bookToRemove = nil
            }
        } message: {
            Text("Are you sure you want to remove this book from your library? This action cannot be undone.")
        }
    }
}

struct ElegantLoadingView: View {
    let message: String
    let progress: Double
    let totalBooks: Int
    let currentBookName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Updating Library")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(currentBookName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 50)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(self.progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)
                    .frame(width: 100, height: 100)

                VStack(spacing: 5) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("\(Int(progress * Double(totalBooks)))/\(totalBooks)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 250)
        .padding(25)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .transition(.opacity)
    }
}


struct ElegantErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .transition(.opacity)
    }
}

struct RefreshControl: View {
    var coordinateSpace: CoordinateSpace
    var onRefresh: () -> Void
    @Binding var isPulling: Bool
    @Binding var pullProgress: CGFloat
    
    let threshold: CGFloat = 50
    @State private var refreshTriggered = false
    
    var body: some View {
        GeometryReader { geo in
            let y = geo.frame(in: coordinateSpace).minY
            let progress = min(max(0, y / threshold), 1)
            
            ZStack(alignment: .center) {
                ProgressView()
                    .scaleEffect(progress)
                    .opacity(progress)
            }
            .frame(width: geo.size.width, height: threshold)
            .offset(y: -threshold + (progress * threshold))
            .onChange(of: y) { newValue in
                pullProgress = progress
                
                if newValue > 0 {
                    isPulling = true
                    
                    if y >= threshold && !refreshTriggered {
                        refreshTriggered = true
                        onRefresh()
                    }
                } else {
                    isPulling = false
                    refreshTriggered = false
                }
            }
        }
        .frame(height: 0)
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

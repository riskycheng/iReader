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
                            print("RefreshControl: onRefresh called")
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
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(viewModel.loadingMessage)
                            .font(.headline)
                        Text("\(viewModel.loadedBooksCount)/\(viewModel.totalBooksCount) books refreshed")
                            .font(.subheadline)
                        ProgressView(value: Double(viewModel.loadedBooksCount), total: Double(viewModel.totalBooksCount))
                            .frame(width: 200)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .transition(.opacity)
                    .zIndex(1)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .zIndex(1)
                }
            }
            .navigationTitle("书架")
        }
        .onAppear {
            print("BookLibrariesView appeared")
            viewModel.setLibraryManager(libraryManager)
        }
        .onChange(of: viewModel.isLoading) { newValue in
            print("View detected isLoading changed to: \(newValue)")
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
                print("Pull progress: \(progress), Y value: \(y), Threshold: \(threshold)")
                
                if newValue > 0 {
                    isPulling = true
                    print("Pulling")
                    
                    if y >= threshold && !refreshTriggered {
                        print("Threshold reached, triggering refresh")
                        refreshTriggered = true
                        onRefresh()
                    }
                } else {
                    isPulling = false
                    refreshTriggered = false
                    print("Stopped pulling")
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

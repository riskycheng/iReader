import SwiftUI

struct ReadingView: View {
    let book: Book
    let chapterLink: String?
    
    @State private var currentPage = 0
    @State private var article: Article? = nil
    @State private var isLoading = true
    @State private var showToolbars = false
    @State private var showChapters = false
    @State private var showFontSelector = false
    @State private var showColorPicker = false
    @State private var selectedBackgroundColor: Color = .white
    @State private var selectedFontSize: CGFloat = 16
    @State private var selectedFont: UIFont = .systemFont(ofSize: 16)
    
    @State private var currentChapterIndex: Int? = nil

    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color
                selectedBackgroundColor
                    .ignoresSafeArea()
                
                // Content
                VStack {
                    if isLoading {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if let article = article {
                        TabView(selection: $currentPage) {
                            // Title page
                            VStack {
                                Text(article.title)
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                            }
                            .tag(0)
                            
                            // Content pages
                            ForEach(0..<article.splitPages.count, id: \.self) { index in
                                VStack(alignment: .leading) {
                                    Text(article.splitPages[index])
                                        .font(.custom(selectedFont.fontName, size: selectedFontSize))
                                        .lineSpacing(6)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .padding(.horizontal, 10)
                                        .background(selectedBackgroundColor)
                                        .tag(index + 1)
                                    
                                    // Append Prev and Next buttons at the end of the last page
                                    if index == article.splitPages.count - 1 {
                                        HStack {
                                            if let currentChapterIndex = currentChapterIndex, currentChapterIndex > 0 {
                                                Button(action: {
                                                    navigateToChapter(at: currentChapterIndex - 1, geometry: geometry)
                                                }) {
                                                    Text("Prev")
                                                        .foregroundColor(.blue)
                                                        .padding(.horizontal)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if let currentChapterIndex = currentChapterIndex, currentChapterIndex < book.chapters.count - 1 {
                                                Button(action: {
                                                    navigateToChapter(at: currentChapterIndex + 1, geometry: geometry)
                                                }) {
                                                    Text("Next")
                                                        .foregroundColor(.blue)
                                                        .padding(.horizontal)
                                                }
                                            }
                                        }
                                        .padding(.vertical)
                                        .onTapGesture {} // Prevent triggering toolbar toggle when clicking these buttons
                                    }
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .gesture(
                            DragGesture()
                                .onChanged { _ in
                                    // Disable toolbar toggling when swiping
                                    showToolbars = false
                                }
                        )
                    }
                }
                
                // Top toolbar
                if showToolbars {
                    VStack {
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss() // Properly navigate back to BookLibraryView
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.blue)
                            }
                            .padding(.leading)
                            
                            Spacer()
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 10)
                        .background(Color.white)
                        
                        Spacer()
                    }
                }
                
                // Bottom toolbar
                if showToolbars {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Button(action: {
                                showChapters.toggle()
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showColorPicker.toggle()
                            }) {
                                Image(systemName: "paintpalette")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showFontSelector.toggle()
                            }) {
                                Image(systemName: "textformat.size")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.white)
                    }
                    .padding(.bottom, 5)
                }
            }
            .onTapGesture {
                // Toggle toolbars only when tapping the central region of the chapter content
                withAnimation {
                    showToolbars.toggle()
                }
            }
            .onAppear {
                if let chapterLink = chapterLink, let index = book.chapters.firstIndex(where: { $0.link == chapterLink }) {
                    currentChapterIndex = index
                    loadContent(from: chapterLink, width: geometry.size.width, height: geometry.size.height)
                }
            }
            .sheet(isPresented: $showChapters) {
                ChapterListView(chapters: book.chapters) { chapter in
                    showChapters = false
                    if let index = book.chapters.firstIndex(where: { $0.link == chapter.link }) {
                        navigateToChapter(at: index, geometry: geometry)
                    }
                }
            }
            .sheet(isPresented: $showFontSelector) {
                FontSelectorView(selectedFont: $selectedFont, selectedFontSize: $selectedFontSize)
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPicker("Select Background Color", selection: $selectedBackgroundColor)
                    .padding()
            }
        }
        .navigationBarHidden(true)
    }
    
    private func loadContent(from link: String?, width: CGFloat, height: CGFloat) {
        guard let link = link, let url = URL(string: link) else { return }
        
        isLoading = true
        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, _, error in
            if let data = data {
                let parser = HTMLParser()
                switch parser.parseHTML(data: data, baseURL: link, width: width, height: height) {
                case .success(let article):
                    DispatchQueue.main.async {
                        self.article = article
                        self.isLoading = false
                        self.currentPage = 0 // Reset to the first page when new content is loaded
                        showToolbars = false // Ensure toolbars are hidden when new content loads
                    }
                case .failure(let error):
                    print("Parsing error: \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }.resume()
    }
    
    private func navigateToChapter(at index: Int, geometry: GeometryProxy) {
        currentChapterIndex = index
        loadContent(from: book.chapters[index].link, width: geometry.size.width, height: geometry.size.height)
    }
}

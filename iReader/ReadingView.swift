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
                            .onAppear {
                                print("ReadingView: Loading spinner displayed")
                            }
                    } else if let article = article {
                        TabView(selection: $currentPage) {
                            // Title page
                            VStack {
                                Text(article.title)
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .onAppear {
                                        print("ReadingView: Title page displayed - \(article.title)")
                                    }
                            }
                            .tag(0)
                            
                            // Content pages
                            ForEach(0..<article.splitPages.count, id: \.self) { index in
                                VStack(alignment: .leading) {
                                    Text(article.splitPages[index])
                                        .font(.custom(selectedFont.fontName, size: selectedFontSize))
                                        .lineSpacing(6)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .background(selectedBackgroundColor)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        
                                    
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
                                .tag(index + 1)
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
                                print("ReadingView: Back button pressed")
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
                                print("ReadingView: Chapter list toggled")
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showColorPicker.toggle()
                                print("ReadingView: Color picker toggled")
                            }) {
                                Image(systemName: "paintpalette")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showFontSelector.toggle()
                                print("ReadingView: Font selector toggled")
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
                    print("ReadingView: Toolbars toggled to \(showToolbars ? "visible" : "hidden")")
                }
            }
            .onAppear {
                print("ReadingView: View appeared, starting content load")
                if let chapterLink = chapterLink, let index = book.chapters.firstIndex(where: { $0.link == chapterLink }) {
                    currentChapterIndex = index
                    print("ReadingView: Navigating to chapter index \(index) with link \(chapterLink).")
                    loadContent(from: chapterLink, width: geometry.size.width, height: geometry.size.height)
                } else {
                    print("ReadingView: Invalid or missing chapter link.")
                }
            }
            .sheet(isPresented: $showChapters) {
                ChapterListView(chapters: book.chapters) { chapter in
                    showChapters = false
                    if let index = book.chapters.firstIndex(where: { $0.link == chapter.link }) {
                        print("ReadingView: User selected chapter at index \(index).")
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
        guard let link = link, let url = URL(string: link) else {
            print("ReadingView: Invalid URL link.")
            return
        }
        
        isLoading = true
        print("ReadingView: Loading content from \(link).")
        
        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, _, error in
            if let error = error {
                print("ReadingView: Failed to load content from URL - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            if let data = data {
                print("ReadingView: Content loaded, starting to parse.")
                let parser = HTMLParser()
                switch parser.parseHTML(data: data, baseURL: link, width: width, height: height) {
                case .success(let article):
                    DispatchQueue.main.async {
                        self.article = article
                        self.isLoading = false
                        self.currentPage = 0 // Reset to the first page when new content is loaded
                        showToolbars = false // Ensure toolbars are hidden when new content loads
                        print("ReadingView: Successfully loaded article with \(article.splitPages.count) pages.")
                    }
                case .failure(let error):
                    print("ReadingView: Parsing error - \(error)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } else {
                print("ReadingView: No data received from URL.")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func navigateToChapter(at index: Int, geometry: GeometryProxy) {
        currentChapterIndex = index
        print("ReadingView: Navigating to chapter at index \(index) with link \(book.chapters[index].link).")
        loadContent(from: book.chapters[index].link, width: geometry.size.width, height: geometry.size.height)
    }
}

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
    
    private let toolbarHeight: CGFloat = 44
    private let bottomToolbarHeight: CGFloat = 44
    private let tabViewHeight: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                selectedBackgroundColor.ignoresSafeArea()
                
                VStack {
                    if isLoading {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if let article = article {
                        TabView(selection: $currentPage) {
                            VStack {
                                Text(article.title)
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }
                            .tag(0)
                            
                            ForEach(0..<article.splitPages.count, id: \.self) { index in
                                ScrollView {
                                    VStack(alignment: .leading) {
                                        Text(article.splitPages[index])
                                            .font(.custom(selectedFont.fontName, size: selectedFontSize))
                                            .lineSpacing(2)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                                .tag(index + 1)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .gesture(DragGesture().onChanged { _ in showToolbars = false })
                    }
                }
                
                if showToolbars {
                    VStack {
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
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
                    
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: { showChapters.toggle() }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            Button(action: { showColorPicker.toggle() }) {
                                Image(systemName: "paintpalette")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            Button(action: { showFontSelector.toggle() }) {
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
                
                if let article = article, let currentChapterIndex = currentChapterIndex,
                   currentPage == article.splitPages.count {
                    VStack {
                        Spacer()
                        HStack {
                            if currentChapterIndex > 0 {
                                Button(action: {
                                    navigateToChapter(at: currentChapterIndex - 1, geometry: geometry)
                                }) {
                                    Text("Prev")
                                        .foregroundColor(.blue)
                                        .padding(.horizontal)
                                }
                            }
                            Spacer()
                            if currentChapterIndex < book.chapters.count - 1 {
                                Button(action: {
                                    navigateToChapter(at: currentChapterIndex + 1, geometry: geometry)
                                }) {
                                    Text("Next")
                                        .foregroundColor(.blue)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .frame(height: toolbarHeight)
                        .background(Color.white.opacity(0.8))
                    }
                }
            }
            .onTapGesture {
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
        article = nil // Reset the article to ensure fresh splitting

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("ReadingView: Failed to load content - \(error.localizedDescription)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            if let data = data {
                let parser = HTMLParser()
                switch parser.parseHTML(data: data, baseURL: link, width: width, height: height, toolbarHeight: toolbarHeight, bottomToolbarHeight: bottomToolbarHeight, tabViewHeight: tabViewHeight) {
                case .success(let article):
                    DispatchQueue.main.async {
                        self.article = article
                        self.isLoading = false
                        self.currentPage = 0
                        self.showToolbars = false
                    }
                case .failure(let error):
                    print("ReadingView: Parsing error - \(error)")
                    DispatchQueue.main.async { self.isLoading = false }
                }
            } else {
                print("ReadingView: No data received from URL.")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }
    
    private func navigateToChapter(at index: Int, geometry: GeometryProxy) {
        currentChapterIndex = index
        currentPage = 0
        article = nil  // Reset the article to force a recalculation
        loadContent(from: book.chapters[index].link, width: geometry.size.width, height: geometry.size.height)
    }
}

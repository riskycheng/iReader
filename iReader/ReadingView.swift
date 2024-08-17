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
                                Spacer()
                                Text(article.title)
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                Spacer()
                            }
                            .tag(0)
                            
                            // Content pages
                            ForEach(0..<article.splitPages.count, id: \.self) { index in
                                VStack {
                                    Text(article.splitPages[index])
                                        .font(.custom(selectedFont.fontName, size: selectedFontSize))
                                        .lineSpacing(6)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .padding(.horizontal, 10)
                                        .background(selectedBackgroundColor)
                                        .tag(index + 1)
                                    
                                    if index == article.splitPages.count - 1 {
                                        HStack {
                                            if let prevLink = article.prevLink {
                                                Button("Prev") {
                                                    loadContent(from: prevLink, width: geometry.size.width, height: geometry.size.height)
                                                }
                                            }
                                            Spacer()
                                            if let nextLink = article.nextLink {
                                                Button("Next") {
                                                    loadContent(from: nextLink, width: geometry.size.width, height: geometry.size.height)
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                }
                
                // Top toolbar
                if showToolbars {
                    VStack {
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss() // Properly navigate back to BookLibraryView
                            }) {
                                Text("< back")
                                    .font(.system(size: 18, weight: .regular))
                            }
                            .padding(.leading)
                            
                            Spacer()
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 10)
                        .background(Color.white) // White background
                        
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
                        .background(Color.white) // White background
                    }
                    .padding(.bottom, 5)
                }
            }
            .onTapGesture {
                withAnimation {
                    showToolbars.toggle()
                }
            }
            .onAppear {
                loadContent(from: chapterLink, width: geometry.size.width, height: geometry.size.height)
            }
            .sheet(isPresented: $showChapters) {
                ChapterListView(chapters: book.chapters) { chapter in
                    loadContent(from: chapter.link, width: geometry.size.width, height: geometry.size.height)
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
}

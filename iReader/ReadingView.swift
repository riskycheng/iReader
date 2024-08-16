import SwiftUI

struct ReadingView: View {
    let book: Book
    let chapterLink: String?
    
    @State private var currentPage = 0
    @State private var article: Article? = nil
    @State private var isLoading = true
    @State private var showToolbar = false
    @State private var showMenu = false
    
    @State private var showChapterList = false
    @State private var showBackgroundColorPicker = false
    @State private var showFontSizePicker = false
    @State private var showFontStylePicker = false
    
    @State private var selectedFontSize: CGFloat = 18
    @State private var selectedBackgroundColor = Color.white
    @State private var selectedFontName: String = "System"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                selectedBackgroundColor
                    .ignoresSafeArea()

                VStack {
                    if isLoading {
                        Text("Loading...")
                    } else if let article = article {
                        TabView(selection: $currentPage) {
                            VStack {
                                Spacer()
                                Text(article.title)
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                Spacer()
                            }
                            .tag(0)
                            
                            ForEach(0..<article.splitPages.count, id: \.self) { index in
                                VStack {
                                    Text(article.splitPages[index])
                                        .font(.custom(selectedFontName, size: selectedFontSize))
                                        .lineSpacing(8)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .padding(.horizontal, 10)
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
                .onAppear {
                    if let chapterLink = chapterLink {
                        loadContent(from: chapterLink, width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // Navigate back to the previous view
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                if let navigationController = windowScene.windows.first?.rootViewController as? UINavigationController {
                                    navigationController.popViewController(animated: true)
                                }
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                .navigationBarHidden(!showToolbar)
                .onTapGesture {
                    // Toggle showing/hiding the toolbar and bottom menu
                    withAnimation {
                        showToolbar.toggle()
                        showMenu.toggle()
                    }
                }
                
                // Bottom menu
                if showMenu {
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: { showChapterList.toggle() }) {
                                Image(systemName: "list.bullet")
                            }
                            Spacer()
                            Button(action: { showBackgroundColorPicker.toggle() }) {
                                Image(systemName: "paintbrush")
                            }
                            Spacer()
                            Button(action: { showFontSizePicker.toggle() }) {
                                Image(systemName: "textformat.size")
                            }
                            Spacer()
                            Button(action: { showFontStylePicker.toggle() }) {
                                Image(systemName: "textformat")
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showChapterList) {
            // Placeholder for the chapter list view (drawer style)
            VStack {
                Text("Chapter List").font(.title)
                List(book.chapters, id: \.link) { chapter in
                    Button(chapter.title) {
                        // Load the selected chapter content
                        loadContent(from: chapter.link, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        showChapterList = false
                    }
                }
            }
        }
        .sheet(isPresented: $showBackgroundColorPicker) {
            VStack {
                Text("Select Background Color")
                ColorPicker("Pick a color", selection: $selectedBackgroundColor)
                    .padding()
            }
            .padding()
        }
        .sheet(isPresented: $showFontSizePicker) {
            VStack {
                Text("Select Font Size")
                Slider(value: $selectedFontSize, in: 12...36)
                    .padding()
            }
            .padding()
        }
        .sheet(isPresented: $showFontStylePicker) {
            VStack {
                Text("Select Font Style")
                Picker("Font Style", selection: $selectedFontName) {
                    Text("System").tag("System")
                    Text("Times New Roman").tag("Times New Roman")
                    Text("Helvetica").tag("Helvetica")
                    // Add more font options as needed
                }
                .pickerStyle(WheelPickerStyle())
            }
            .padding()
        }
    }

    private func loadContent(from urlString: String, width: CGFloat, height: CGFloat) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")"

        DispatchQueue.main.async {
            self.currentPage = 0
            self.article = nil
            self.isLoading = true
        }

        let session = URLSession(configuration: .default)
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            let parser = HTMLParser()
            switch parser.parseHTML(data: data, baseURL: baseURL, width: width, height: height - parser.measureSingleLineWithTwoLineSpacesHeight()) {
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
        }.resume()
    }
}

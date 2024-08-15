import SwiftUI
import WebKit

class WebViewModel: ObservableObject {
    @Published var urls: [URL] = [
        URL(string: "https://www.baidu.com")!,
        URL(string: "https://www.icloud.com")!,
        URL(string: "https://www.example.com")!
    ]
    @Published var selectedURL: URL?
    @Published var isFullScreen: Bool = false

    func addNewPage() {
        let newURLString = "https://www.newpage\(urls.count + 1).com"
        if let newURL = URL(string: newURLString) {
            urls.append(newURL)
        }
    }
}

struct GridView: View {
    @ObservedObject var viewModel: WebViewModel
    let onSelect: (URL) -> Void

    var body: some View {
        GeometryReader { geometry in
            let columns = [
                GridItem(.adaptive(minimum: 160), spacing: 20)
            ]

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.urls, id: \.self) { url in
                        Button(action: {
                            onSelect(url)
                        }) {
                            VStack {
                                WebViewContainer(url: .constant(url), currentURL: .constant(nil))
                                    .frame(height: 150)
                                    .cornerRadius(10)
                                    .padding()
                                Text(url.host ?? "")
                                    .font(.caption)
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                    }
                }
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 0, trailing: 20))
            }
        }
    }
}

struct MultipleWindowsView: View {
    @StateObject private var viewModel = WebViewModel()
    @Binding var books: [Book] // Bind the books array to pass and update it

    @State private var selectedTab = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("普通窗口").tag(0)
                    Text("无痕窗口").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(EdgeInsets(top: 0, leading: 80, bottom: 0, trailing: 80))
                .background(
                    HStack {
                        Spacer()
                        if selectedTab == 0 {
                            Button(action: {
                                if viewModel.isFullScreen {
                                    viewModel.isFullScreen.toggle()
                                } else {
                                    viewModel.addNewPage()
                                }
                            }) {
                                Image(systemName: viewModel.isFullScreen ? "rectangle.stack" : "plus")
                                    .padding(.trailing, 20)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                )

                if viewModel.isFullScreen {
                    WebViewContainer(url: $viewModel.selectedURL, currentURL: .constant(nil))
                } else {
                    GridView(viewModel: viewModel) { url in
                        viewModel.selectedURL = url
                        viewModel.isFullScreen = true
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

import Foundation
import Combine

class BookLoader: ObservableObject {
    @Published var book: Book?
    @Published var chapterContent: String?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadBook(baseURL: String, bookURL: String) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: bookURL) else {
            error = URLError(.badURL)
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data -> String in
                guard let html = String(data: data, encoding: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }
                return html
            }
            .tryMap { html -> Book in
                guard let book = HTMLBookParser.parseHTML(html, baseURL: baseURL, bookURL: bookURL) else {
                    throw URLError(.cannotParseResponse)
                }
                return book
            }
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.error = error
                }
            } receiveValue: { [weak self] book in
                self?.book = book
            }
            .store(in: &cancellables)
    }
    
    func loadChapterContent(chapterURL: String, baseURL: String) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: chapterURL) else {
            error = URLError(.badURL)
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data -> String in
                guard let html = String(data: data, encoding: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }
                return html
            }
            .tryMap { html -> String in
                guard let chapterData = HTMLBookParser.parseChapterContent(html, baseURL: baseURL) else {
                    throw URLError(.cannotParseResponse)
                }
                return chapterData.content
            }
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.error = error
                }
            } receiveValue: { [weak self] content in
                self?.chapterContent = content
            }
            .store(in: &cancellables)
    }
}

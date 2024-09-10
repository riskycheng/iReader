//
//  BookLibrariesViewModel.swift
//  iReader
//
//  Created by Jian Cheng on 2024/9/10.
//

import Foundation
import SwiftUI

class BookLibrariesViewModel: ObservableObject {
    @Published var books: [Book] = []
       @Published var isLoading = false
       @Published var errorMessage: String?
       @Published var loadingMessage = "Loading books..."
       @Published var loadedBooksCount = 0
       @Published var totalBooksCount = 0
       
       private weak var libraryManager: LibraryManager?
    private let minimumLoadingDuration: TimeInterval = 0.5
       
       private let bookURLs = [
           "https://www.bqgda.cc/books/9680/",
           "https://www.bqgda.cc/books/160252/",
           "https://www.bqgda.cc/books/16457/",
           "https://www.bqgda.cc/books/173469/"
       ]
       
       private let baseURL = "https://www.bqgda.cc/"
       private let cacheKey = "CachedBooks"
       private let cacheTimestampKey = "CachedBooksTimestamp"
       private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
       
       func setLibraryManager(_ manager: LibraryManager) {
           self.libraryManager = manager
       }
       
    func loadBooks() {
          self.books = libraryManager?.books ?? []
      }
      
        
    
    func refreshBooks() async {
           let startTime = Date()
           
           await MainActor.run {
               isLoading = true
               errorMessage = nil
               loadingMessage = "Refreshing all books..."
               loadedBooksCount = 0
           }
           
           do {
               try await libraryManager?.refreshBooks()
               await MainActor.run {
                   self.books = libraryManager?.books ?? []
                   loadingMessage = "All books updated"
                   loadedBooksCount = self.books.count
                   totalBooksCount = self.books.count
               }
           } catch {
               await handleRefreshError(error)
           }
           
           // Ensure minimum loading duration
           let elapsedTime = Date().timeIntervalSince(startTime)
           if elapsedTime < minimumLoadingDuration {
               try? await Task.sleep(nanoseconds: UInt64((minimumLoadingDuration - elapsedTime) * 1_000_000_000))
           }
           
           await MainActor.run {
               isLoading = false
           }
       }
     
    func removeBook(_ book: Book) {
          libraryManager?.removeBook(book)
          books.removeAll { $0.id == book.id }
      }
    
    
        @MainActor
        private func updateTotalCount(_ count: Int) {
            totalBooksCount = count
        }
        
        @MainActor
        private func updateLoadingProgress(_ count: Int, bookTitle: String) {
            loadedBooksCount = count
            loadingMessage = "Loaded \(bookTitle)"
        }
        
        @MainActor
        private func finalizeRefresh(_ refreshedBooks: [Book]) {
            self.books = refreshedBooks
            cacheBooks(self.books)
            loadingMessage = "All books updated"
            isLoading = false
            loadedBooksCount = self.books.count
            totalBooksCount = self.books.count
        }
        
    @MainActor
       private func handleRefreshError(_ error: Error) {
           errorMessage = "Error refreshing books: \(error.localizedDescription)"
           loadingMessage = "Error occurred"
           isLoading = false
       }
    
        private func mergeBooksWithLibrary(_ fetchedBooks: [Book]) -> [Book] {
            var mergedBooks = fetchedBooks
            if let libraryBooks = libraryManager?.books {
                for libraryBook in libraryBooks {
                    if !mergedBooks.contains(where: { $0.title == libraryBook.title }) {
                        mergedBooks.append(libraryBook)
                    }
                }
            }
            return mergedBooks
        }
    
   
    private func fetchBooksFromNetworkAsync() async throws -> [Book] {
            var fetchedBooks: [Book] = []
            for (index, bookURL) in bookURLs.enumerated() {
                guard let url = URL(string: bookURL) else { continue }
                let (data, _) = try await URLSession.shared.data(from: url)
                if let html = String(data: data, encoding: .utf8),
                   let book = HTMLBookParser.parseBasicBookInfo(html, baseURL: baseURL, bookURL: bookURL) {
                    fetchedBooks.append(book)
                    await MainActor.run {
                        loadedBooksCount = index + 1
                        loadingMessage = "Loaded \(book.title)"
                    }
                }
            }
            return fetchedBooks
        }
    
    
    
    private func updateBooksInPlace(with newBooks: [Book]) {
        var updatedBooks = books
        
        for newBook in newBooks {
            if let index = updatedBooks.firstIndex(where: { $0.id == newBook.id }) {
                updatedBooks[index] = newBook
            } else {
                updatedBooks.append(newBook)
            }
        }
        
        // Remove books that are no longer in the new list
        updatedBooks.removeAll { book in
            !newBooks.contains { $0.id == book.id }
        }
        
        books = updatedBooks
        loadedBooksCount = updatedBooks.count
        totalBooksCount = updatedBooks.count
    }

    
    
    
    private func loadCachedBooks() -> [Book]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            print("No cached books found")
            return nil
        }
        
        do {
            let cachedBooks = try JSONDecoder().decode([Book].self, from: data)
            print("Successfully loaded \(cachedBooks.count) books from cache")
            return cachedBooks
        } catch {
            print("Error decoding cached books: \(error)")
            return nil
        }
    }
    
    private func cacheBooks(_ books: [Book]) {
        do {
            let data = try JSONEncoder().encode(books)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
            print("Successfully cached \(books.count) books")
        } catch {
            print("Error caching books: \(error)")
        }
    }
    
    private func isCacheValid() -> Bool {
        guard let cachedBooks = loadCachedBooks(), !cachedBooks.isEmpty else {
            return false
        }
        
        let cachedTimestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        let currentTimestamp = Date().timeIntervalSince1970
        
        return (currentTimestamp - cachedTimestamp) < cacheDuration
    }
    
    private func printBooksInfo(_ books: [Book]) {
        for (index, book) in books.enumerated() {
            print("\nBook #\(index + 1) Info:")
            print("Title: \(book.title)")
            print("Author: \(book.author)")
            print("Cover URL: \(book.coverURL)")
            print("Last Updated: \(book.lastUpdated)")
            print("Status: \(book.status)")
            print("Introduction: \(book.introduction.prefix(100))...")
            print("Book Link: \(book.link)")
            print("Number of Chapters: \(book.chapters.count)")
            if let firstChapter = book.chapters.first {
                print("First Chapter Title: \(firstChapter.title)")
                print("First Chapter Link: \(firstChapter.link)")
            }
            if let lastChapter = book.chapters.last, book.chapters.count > 1 {
                print("Last Chapter Title: \(lastChapter.title)")
                print("Last Chapter Link: \(lastChapter.link)")
            }
            print("--------------------")
        }
    }
}

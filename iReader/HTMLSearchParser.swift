import Foundation
import SwiftSoup

class HTMLSearchParser {
    static func parseSearchResults(html: String, baseURL: String, update: @escaping ([Book]) -> Void, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                #if DEBUG
                print("开始解析HTML，长度: \(html.count)")
                #endif
                
                let doc: Document = try SwiftSoup.parse(html)
                let bookElements: Elements = try doc.select("div.bookbox")
                
                #if DEBUG
                print("找到书籍元素数量: \(bookElements.count)")
                
                // 如果没有找到书籍元素，尝试查找其他可能的元素
                if bookElements.count == 0 {
                    // 尝试查找其他可能的元素
                    let alternativeElements = try doc.select("div.result-list div.result-item")
                    print("尝试查找替代元素 'div.result-list div.result-item': \(alternativeElements.count)")
                    
                    // 查找页面中的所有div元素及其class
                    let allDivs = try doc.select("div[class]")
                    print("页面中所有带class的div元素: \(allDivs.count)")
                    let divClasses = allDivs.array().compactMap { try? $0.attr("class") }
                    let uniqueClasses = Set(divClasses)
                    print("页面中div元素的class列表: \(uniqueClasses.joined(separator: ", "))")
                    
                    // 查找页面中可能包含书籍信息的元素
                    let possibleBookContainers = try doc.select("div:has(img)")
                    print("可能包含书籍信息的元素(带图片的div): \(possibleBookContainers.count)")
                }
                #endif
                
                var books: [Book] = []
                
                for element in bookElements {
                    if let book = parseBookBox(element, baseURL: baseURL) {
                        books.append(book)
                    }
                }
                
                DispatchQueue.main.async {
                    update(books)
                    completion()
                }
            } catch {
                // 只在调试模式下输出错误
                #if DEBUG
                print("解析HTML时出错: \(error)")
                #endif
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    private static func parseBookBox(_ bookbox: Element, baseURL: String) -> Book? {
        do {
            #if DEBUG
            print("解析书籍元素: \(try bookbox.html().prefix(100))...")
            #endif
            
            let linkElement: Element = try bookbox.select("a").first() ?? Element(Tag("a"), "")
            let bookLink: String = try baseURL + linkElement.attr("href")
            
            let coverElement: Element = try bookbox.select("img").first() ?? Element(Tag("img"), "")
            let coverURL: String = try coverElement.attr("src")
            
            let bookInfoElement: Element = try bookbox.select("div.bookinfo").first() ?? Element(Tag("div"), "")
            let bookName: String = try bookInfoElement.select("h4.bookname").text()
            
            let author: String = try bookInfoElement.select("div.author").text().replacingOccurrences(of: "作者：", with: "")
            
            let introduction: String = try bookInfoElement.select("div.uptime").text()
            
            #if DEBUG
            print("成功解析书籍: \(bookName) by \(author)")
            #endif
            
            return Book(
                title: bookName,
                author: author,
                coverURL: coverURL,
                lastUpdated: "",
                status: "",
                introduction: introduction,
                chapters: [],
                link: bookLink
            )
        } catch {
            // 只在调试模式下输出错误
            #if DEBUG
            print("解析单个书籍时出错: \(error)")
            #endif
            return nil
        }
    }
    
    // 添加一个新方法，尝试使用不同的选择器解析搜索结果
    static func parseSearchResultsAlternative(html: String, baseURL: String) -> [Book] {
        do {
            let doc: Document = try SwiftSoup.parse(html)
            var books: [Book] = []
            
            // 尝试多种可能的选择器
            let selectors = [
                "div.bookbox", 
                "div.result-item", 
                "div.book-item",
                "div:has(img):has(a):has(div.bookinfo)",
                "div:has(img):has(a)"
            ]
            
            for selector in selectors {
                let elements = try doc.select(selector)
                #if DEBUG
                print("使用选择器 '\(selector)' 找到元素: \(elements.count)")
                #endif
                
                if elements.count > 0 {
                    for element in elements {
                        if let book = tryParseBookElement(element, baseURL: baseURL) {
                            books.append(book)
                        }
                    }
                    
                    if !books.isEmpty {
                        #if DEBUG
                        print("使用选择器 '\(selector)' 成功解析 \(books.count) 本书")
                        #endif
                        break
                    }
                }
            }
            
            return books
        } catch {
            #if DEBUG
            print("替代解析方法出错: \(error)")
            #endif
            return []
        }
    }
    
    // 尝试解析书籍元素的通用方法
    private static func tryParseBookElement(_ element: Element, baseURL: String) -> Book? {
        do {
            // 尝试获取链接
            let linkElement = try element.select("a").first()
            let bookLink = linkElement != nil ? baseURL + (try linkElement!.attr("href")) : ""
            
            // 尝试获取封面图片
            let coverElement = try element.select("img").first()
            let coverURL = coverElement != nil ? try coverElement!.attr("src") : ""
            
            // 尝试获取书名
            var bookName = ""
            for nameSelector in ["h4.bookname", "h3", "h4", "div.name", ".title", "a[title]"] {
                let nameElement = try element.select(nameSelector).first()
                if nameElement != nil {
                    bookName = try nameElement!.text()
                    if !bookName.isEmpty {
                        break
                    }
                    
                    // 如果文本为空，尝试获取title属性
                    if nameSelector == "a[title]" {
                        bookName = try nameElement!.attr("title")
                        if !bookName.isEmpty {
                            break
                        }
                    }
                }
            }
            
            // 尝试获取作者
            var author = ""
            for authorSelector in ["div.author", ".author", "p.author", "span.author", "div:contains(作者)"] {
                let authorElement = try element.select(authorSelector).first()
                if authorElement != nil {
                    author = try authorElement!.text()
                    author = author.replacingOccurrences(of: "作者：", with: "")
                    if !author.isEmpty {
                        break
                    }
                }
            }
            
            // 尝试获取简介
            var introduction = ""
            for introSelector in ["div.uptime", "div.intro", "p.intro", ".desc", "div.description"] {
                let introElement = try element.select(introSelector).first()
                if introElement != nil {
                    introduction = try introElement!.text()
                    if !introduction.isEmpty {
                        break
                    }
                }
            }
            
            // 如果至少有书名和链接，就创建一个Book对象
            if !bookName.isEmpty && !bookLink.isEmpty {
                #if DEBUG
                print("成功解析书籍: \(bookName) by \(author)")
                #endif
                
                return Book(
                    title: bookName,
                    author: author,
                    coverURL: coverURL,
                    lastUpdated: "",
                    status: "",
                    introduction: introduction,
                    chapters: [],
                    link: bookLink
                )
            }
            
            return nil
        } catch {
            #if DEBUG
            print("尝试解析书籍元素时出错: \(error)")
            #endif
            return nil
        }
    }
}

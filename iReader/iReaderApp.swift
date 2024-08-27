//
//  iReaderApp.swift
//  iReader
//
//  Created by Jian Cheng on 2024/8/3.
//

import SwiftUI

@main
struct iReaderApp: App {
    var body: some Scene {
        WindowGroup {
            BookReadingView(
                bookTitle: "万相之王",
                chapterTitle: "第一章 我有三个相宫",
                content: BookContent.fullContent
            )
        }
    }
}

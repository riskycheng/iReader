import SwiftUI

struct ChapterListView: View {
    let chapters: [(title: String, link: String)]
    let onSelectChapter: (Chapter) -> Void
    
    var body: some View {
        NavigationView {
            List(chapters, id: \.link) { chapter in
                Button(action: {
                    onSelectChapter(chapter)
                }) {
                    Text(chapter.title)
                        .padding(.vertical, 5)
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

typealias Chapter = (title: String, link: String)

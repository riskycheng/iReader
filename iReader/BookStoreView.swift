import SwiftUI

struct BookStoreView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Featured sections
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        FeaturedItem(title: "在读榜", subtitle: "Top List", image: Image("toplist"))
                        FeaturedItem(title: "新书榜", subtitle: "New Release", image: Image("newrelease"))
                        FeaturedItem(title: "共读", subtitle: "Reading Lab", image: Image("readinglab"))
                        FeaturedItem(title: "故事", subtitle: "My Story", image: Image("mystory"))
                    }
                    .padding()
                    
                    // Categories
                    Text("分类")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        CategoryItem(title: "Turbo专享", image: Image("turbo"))
                        CategoryItem(title: "豆瓣8.0+", image: Image("douban"))
                        CategoryItem(title: "小说", image: Image("novel"))
                        CategoryItem(title: "漫画绘本", image: Image("comic"))
                        CategoryItem(title: "青春", image: Image("youth"))
                        CategoryItem(title: "推理幻想", image: Image("mystery"))
                        CategoryItem(title: "短篇集", image: Image("shortstories"))
                        CategoryItem(title: "历史", image: Image("history"))
                        CategoryItem(title: "国风文化", image: Image("culture"))
                    }
                    .padding()
                }
            }
            .searchable(text: $searchText, prompt: "搜索")
            .navigationTitle("书城")
        }
    }
}

struct FeaturedItem: View {
    let title: String
    let subtitle: String
    let image: Image
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .cornerRadius(10)
                .overlay(Color.black.opacity(0.3))
                .cornerRadius(10)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
}

struct CategoryItem: View {
    let title: String
    let image: Image
    
    var body: some View {
        VStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
                .cornerRadius(10)
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct BookStoreView_Previews: PreviewProvider {
    static var previews: some View {
        BookStoreView()
    }
}

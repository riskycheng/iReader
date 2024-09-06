import SwiftUI

struct BookStoreView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Featured sections
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        FeaturedItem(title: "在读榜", subtitle: "Top List", color: .black)
                        FeaturedItem(title: "新书榜", subtitle: "New Release", color: .gray)
                        FeaturedItem(title: "共读", subtitle: "Reading Lab", color: .gray)
                        FeaturedItem(title: "故事", subtitle: "My Story", color: .charcoal)
                    }
                    .padding()
                    
                    // Categories
                    Text("分类")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        CategoryItem(title: "Turbo专享", color: .gray)
                        CategoryItem(title: "豆瓣8.0+", color: .tan)
                        CategoryItem(title: "小说", color: .brown)
                        CategoryItem(title: "漫画绘本", color: .orange)
                        CategoryItem(title: "青春", color: .pink)
                        CategoryItem(title: "推理幻想", color: .charcoal)
                        CategoryItem(title: "短篇集", color: .gray)
                        CategoryItem(title: "历史", color: .navy)
                        CategoryItem(title: "国风文化", color: .darkRed)
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
    let color: Color
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(color)
                .frame(height: 120)
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
    let color: Color
    
    var body: some View {
        VStack {
            Rectangle()
                .fill(color)
                .frame(height: 100)
                .cornerRadius(10)
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

extension Color {
    static let charcoal = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let tan = Color(red: 0.82, green: 0.71, blue: 0.55)
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.5)
    static let darkRed = Color(red: 0.5, green: 0.0, blue: 0.0)
}

struct BookStoreView_Previews: PreviewProvider {
    static var previews: some View {
        BookStoreView()
    }
}

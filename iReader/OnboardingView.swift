import SwiftUI

struct OnboardingView: View {
    @Binding var isShowingOnboarding: Bool
    @State private var currentPage = 0
    
    let onboardingData = [
        OnboardingPage(
            image: "books.vertical.fill",
            title: "欢迎使用 iReader",
            description: "简洁优雅的网络小说阅读器",
            gradient: [Color(hex: "FF6B6B"), Color(hex: "4ECDC4")],
            offset: 0
        ),
        OnboardingPage(
            image: "book.fill",
            title: "轻松阅读",
            description: "智能解析，纯净阅读更自然",
            gradient: [Color(hex: "A8E6CF"), Color(hex: "DCEDC1")],
            offset: -10
        ),
        OnboardingPage(
            image: "arrow.triangle.2.circlepath",
            title: "自动更新",
            description: "智能更新，最新章节早知道",
            gradient: [Color(hex: "FFD93D"), Color(hex: "FF6B6B")],
            offset: -10
        ),
        OnboardingPage(
            image: "bookmark.fill",
            title: "开始体验",
            description: "让我们开始阅读之旅吧",
            gradient: [Color(hex: "6C5B7B"), Color(hex: "C06C84")],
            offset: -10
        )
    ]
    
    var body: some View {
        ZStack {
            // 优雅的背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "F8F9FC"),  // 明亮的珍珠白
                    Color(hex: "EDF1F7"),  // 柔和的云灰
                    Color(hex: "E4E9F2")   // 淡雅的薄雾蓝
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 添加动态光效背景
            GeometryReader { geometry in
                ZStack {
                    // 上方光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "7F7FD5").opacity(0.05),  // 淡紫色
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 1,
                                endRadius: geometry.size.width
                            )
                        )
                        .frame(width: geometry.size.width * 1.5, height: geometry.size.width * 1.5)
                        .position(x: geometry.size.width * 0.2, y: -geometry.size.height * 0.2)
                        .blur(radius: 50)
                    
                    // 下方光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "91EAE4").opacity(0.05),  // 清新的薄荷绿
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 1,
                                endRadius: geometry.size.width
                            )
                        )
                        .frame(width: geometry.size.width * 1.5, height: geometry.size.width * 1.5)
                        .position(x: geometry.size.width * 0.8, y: geometry.size.height * 1.2)
                        .blur(radius: 50)
                }
            }
            
            // 磨砂玻璃效果遮罩
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.2))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingData.count, id: \.self) { index in
                        OnboardingCardView(
                            page: onboardingData[index],
                            isLastPage: index == onboardingData.count - 1,
                            onStart: {
                                withAnimation(.spring()) {
                                    isShowingOnboarding = false
                                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 自定义页面指示器
                PageIndicator(currentPage: currentPage, pageCount: onboardingData.count)
                    .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
    let gradient: [Color]
    let offset: CGFloat
}

struct OnboardingCardView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    let onStart: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片主体
            VStack {
                // 添加一个固定的顶部间距容器
                Color.clear
                    .frame(height: 40)
                
                // 图标容器
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: page.gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                        .shadow(color: page.gradient[0].opacity(0.3), radius: 15, x: 0, y: 10)
                    
                    Image(systemName: page.image)
                        .font(.system(size: 45, weight: .bold))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .spring(response: 0.8, dampingFraction: 0.6)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                .padding(.top, 40)  // 减小顶部间距
                
                Spacer()
                
                // 文字内容
                VStack(spacing: 20) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(page.description)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isLastPage {
                    StartButton(action: onStart)
                        .padding(.bottom, 40)
                } else {
                    Color.clear
                        .frame(height: 96)
                }
            }
            .frame(width: UIScreen.main.bounds.width - 40, height: 500)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.95))
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(
                        color: Color(hex: "7F7FD5").opacity(0.1),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .offset(y: page.offset)
        }
        .frame(maxHeight: .infinity, alignment: .center)  // 添加这行来确保垂直居中
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct StartButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                action()
            }
        }) {
            Text("开始体验")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 200, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "FF6B6B"), Color(hex: "4ECDC4")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .shadow(color: Color(hex: "FF6B6B").opacity(0.5), radius: 10, x: 0, y: 10)
                )
                .scaleEffect(isPressed ? 0.95 : 1)
        }
    }
}

struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(Color(hex: "7F7FD5").opacity(currentPage == index ? 1 : 0.2))
                    .frame(width: currentPage == index ? 20 : 8, height: 8)
                    .animation(.spring(), value: currentPage)
            }
        }
        .padding(.top, 20)
    }
}

// 用于创建颜色的扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isShowingOnboarding: .constant(true))
    }
} 

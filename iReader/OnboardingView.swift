import SwiftUI

struct OnboardingView: View {
    @Binding var isShowingOnboarding: Bool
    @State private var currentPage = 0
    
    let onboardingData = [
        OnboardingPage(
            image: "books.vertical.fill",
            title: "欢迎使用 iReader",
            description: "一个简洁优雅的网络小说阅读器",
            gradient: [Color(hex: "FF6B6B"), Color(hex: "4ECDC4")],
            offset: 0
        ),
        OnboardingPage(
            image: "book.fill",
            title: "轻松阅读",
            description: "支持多种小说源，阅读体验流畅自然",
            gradient: [Color(hex: "A8E6CF"), Color(hex: "DCEDC1")],
            offset: -10
        ),
        OnboardingPage(
            image: "arrow.triangle.2.circlepath",
            title: "自动更新",
            description: "智能检测小说更新，不错过每一章节",
            gradient: [Color(hex: "FFD93D"), Color(hex: "FF6B6B")],
            offset: -20
        ),
        OnboardingPage(
            image: "bookmark.fill",
            title: "开始体验",
            description: "让我们开始阅读之旅吧",
            gradient: [Color(hex: "6C5B7B"), Color(hex: "C06C84")],
            offset: -30
        )
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "2C3E50")
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
                .padding(.top, 60)
                
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
                .padding(.top, 40)
                .padding(.bottom, 60)
                
                if isLastPage {
                    StartButton(action: onStart)
                        .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
            .offset(y: page.offset)
        }
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
            Text("开始使用")
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
                    .fill(Color.primary.opacity(currentPage == index ? 1 : 0.2))
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
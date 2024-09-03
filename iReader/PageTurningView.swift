import SwiftUI

enum PageTurningMode {
    case bezier
    case horizontal
    case direct
}

// Type-erasing wrapper for Shape
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

struct PageTurningView<Content: View>: View {
    let mode: PageTurningMode
    let content: Content
    @Binding var currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void
    
    @GestureState private var translation: CGFloat = 0
    
    init(mode: PageTurningMode, currentPage: Binding<Int>, totalPages: Int, onPageChange: @escaping (Int) -> Void, @ViewBuilder content: () -> Content) {
        self.mode = mode
        self._currentPage = currentPage
        self.totalPages = totalPages
        self.onPageChange = onPageChange
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(pageMask(in: geometry))
                .animation(.spring(), value: currentPage)
                .contentShape(Rectangle())
                .gesture(dragGesture(in: geometry))
        }
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($translation) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let offset = value.translation.width / geometry.size.width
                let newPage = (CGFloat(currentPage) - offset).rounded()
                let newPageBounded = min(max(newPage, 0), CGFloat(totalPages - 1))
                onPageChange(Int(newPageBounded))
            }
    }
    
    private func pageMask(in geometry: GeometryProxy) -> AnyShape {
        switch mode {
        case .bezier:
            return AnyShape(BezierPageCurveMask(translation: translation, geometry: geometry))
        case .horizontal:
            return AnyShape(HorizontalPageMask(translation: translation, geometry: geometry))
        case .direct:
            return AnyShape(Rectangle())
        }
    }
}

struct BezierPageCurveMask: Shape {
    let translation: CGFloat
    let geometry: GeometryProxy
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let progress = min(max(-translation / width, 0), 1)
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width * (1 - progress), y: 0))
        
        let controlPoint1 = CGPoint(x: width * (1 - progress * 0.5), y: height * 0.25)
        let controlPoint2 = CGPoint(x: width * (1 - progress * 0.5), y: height * 0.75)
        
        path.addCurve(to: CGPoint(x: width * (1 - progress), y: height),
                      control1: controlPoint1,
                      control2: controlPoint2)
        
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

struct HorizontalPageMask: Shape {
    let translation: CGFloat
    let geometry: GeometryProxy
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRect(CGRect(x: min(0, translation),
                                y: 0,
                                width: geometry.size.width - abs(translation),
                                height: geometry.size.height))
        }
    }
}

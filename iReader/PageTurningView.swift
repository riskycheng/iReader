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
    let onNextChapter: () -> Void
    let onPreviousChapter: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    init(mode: PageTurningMode, currentPage: Binding<Int>, totalPages: Int, onPageChange: @escaping (Int) -> Void, onNextChapter: @escaping () -> Void, onPreviousChapter: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.mode = mode
        self._currentPage = currentPage
        self.totalPages = totalPages
        self.onPageChange = onPageChange
        self.onNextChapter = onNextChapter
        self.onPreviousChapter = onPreviousChapter
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: dragOffset)
                .animation(.interactiveSpring(), value: dragOffset)
                .gesture(dragGesture(in: geometry))
                .clipShape(pageMask(in: geometry))
        }
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                isDragging = true
                if mode != .direct {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                isDragging = false
                let threshold = geometry.size.width * 0.05
                let velocity = value.predictedEndTranslation.width - value.translation.width
                
                if mode == .direct {
                    if value.translation.width > threshold {
                        turnPage(forward: false)
                    } else if value.translation.width < -threshold {
                        turnPage(forward: true)
                    }
                } else if abs(dragOffset) > threshold || abs(velocity) > 100 {
                    if dragOffset > 0 {
                        turnPage(forward: false)
                    } else {
                        turnPage(forward: true)
                    }
                }
                
                withAnimation(.interactiveSpring()) {
                    dragOffset = 0
                }
            }
    }
    
    private func turnPage(forward: Bool) {
        if forward {
            if currentPage < totalPages - 1 {
                onPageChange(currentPage + 1)
            } else {
                onNextChapter()
            }
        } else {
            if currentPage > 0 {
                onPageChange(currentPage - 1)
            } else {
                onPreviousChapter()
            }
        }
    }
    
    private func pageMask(in geometry: GeometryProxy) -> some Shape {
        switch mode {
        case .bezier:
            return AnyShape(BezierPageCurveMask(translation: dragOffset, geometry: geometry))
        case .horizontal:
            return AnyShape(HorizontalPageMask(translation: dragOffset, geometry: geometry))
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

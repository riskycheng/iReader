import SwiftUI

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    var onValueChanged: (Double) -> Void  // 新增这一行
    
    @State private var isDragging = false
    @State private var dragValue: Double?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 外部轮廓
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 40)
                
                // 内部滑动区域
                ZStack(alignment: .leading) {
                    // 背景
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    // 已选择部分
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: max(0, geometry.size.width * CGFloat(((dragValue ?? value) - range.lowerBound) / (range.upperBound - range.lowerBound))))
                }
                .frame(height: 40)
                .mask(RoundedRectangle(cornerRadius: 10))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = calculateValue(gesture: gesture, in: geometry)
                        dragValue = newValue
                        onValueChanged(newValue)  // 添加这一行
                        onEditingChanged(true)
                    }
                    .onEnded { gesture in
                        isDragging = false
                        let newValue = calculateValue(gesture: gesture, in: geometry)
                        dragValue = nil
                        value = newValue
                        onValueChanged(newValue)  // 添加这一行
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 40)
        .animation(.interactiveSpring(), value: value)
    }
    
    private func calculateValue(gesture: DragGesture.Value, in geometry: GeometryProxy) -> Double {
        let proportion = max(0, min(1, gesture.location.x / geometry.size.width))
        return range.lowerBound + (range.upperBound - range.lowerBound) * proportion
    }
}

struct CustomSlider_Previews: PreviewProvider {
    static var previews: some View {
        CustomSlider(value: .constant(0.5), range: 0...1, onEditingChanged: { _ in }, onValueChanged: { _ in })
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}

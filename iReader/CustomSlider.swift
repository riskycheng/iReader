import SwiftUI

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 外部轮廓
                RoundedRectangle(cornerRadius: 20) // 增加圆角以适应更高的高度
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
                        .frame(width: max(0, geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))))
                }
                .frame(height: 40)
                .mask(RoundedRectangle(cornerRadius: 20))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(gesture: gesture, in: geometry)
                    }
                    .onEnded { gesture in
                        isDragging = false
                        updateValue(gesture: gesture, in: geometry)
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 40)
        .animation(isDragging ? nil : .easeInOut, value: value) // 只在非拖动状态下应用动画
    }
    
    private func updateValue(gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let newValue = Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
        value = min(max(newValue, range.lowerBound), range.upperBound)
        onEditingChanged(true)
    }
}

struct CustomSlider_Previews: PreviewProvider {
    static var previews: some View {
        CustomSlider(value: .constant(0.5), range: 0...1) { _ in }
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}

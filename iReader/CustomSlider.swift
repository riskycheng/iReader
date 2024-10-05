import SwiftUI

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 外部轮廓
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 32)
                
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
                .frame(height: 32)
                .mask(RoundedRectangle(cornerRadius: 16))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                        self.value = min(max(newValue, range.lowerBound), range.upperBound)
                        onEditingChanged(true)
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 32)
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

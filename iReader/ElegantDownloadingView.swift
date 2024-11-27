import SwiftUI

struct ElegantDownloadingView: View {
    let progress: Double
    let bookName: String
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("正在下载")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(bookName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 50)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)
                    .frame(width: 100, height: 100)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(.title3, design: .rounded))
                    .bold()
            }
            
            Button(action: onCancel) {
                Text("取消下载")
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 1)
                    )
            }
        }
        .frame(width: 250)
        .padding(25)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

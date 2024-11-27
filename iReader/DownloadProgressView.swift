import SwiftUI

struct DownloadProgressView: View {
    let message: String
    let progress: Double
    let bookName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(bookName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 50)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .frame(width: 250)
        .padding(25)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

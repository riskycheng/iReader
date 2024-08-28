import SwiftUI

struct LogView: View {
    @Binding var logs: String

    var body: some View {
        ScrollView {
            Text(logs)
                .font(.footnote)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
        }
        .frame(height: 200) // Adjust height as needed
    }
}

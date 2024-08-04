import SwiftUI

struct MultipleWindowsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("普通窗口").tag(0)
                    Text("无痕窗口").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(EdgeInsets(top: 0, leading: 80, bottom: 0, trailing: 80))
                .background(
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .padding(.trailing, 20)
                            .frame(height: geometry.size.height / 2, alignment: .center)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    MultipleWindowsView()
}

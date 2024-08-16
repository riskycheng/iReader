import SwiftUI

struct FontSelectorView: View {
    @Binding var selectedFont: UIFont
    @Binding var selectedFontSize: CGFloat
    
    var body: some View {
        VStack {
            Text("Select Font Style")
                .font(.headline)
            
            Picker("Font", selection: $selectedFont) {
                Text("System Default").tag(UIFont.systemFont(ofSize: selectedFontSize))
                Text("Serif").tag(UIFont(name: "Times New Roman", size: selectedFontSize) ?? UIFont.systemFont(ofSize: selectedFontSize))
                Text("Monospaced").tag(UIFont.monospacedSystemFont(ofSize: selectedFontSize, weight: .regular))
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Text("Adjust Font Size")
                .font(.headline)
                .padding(.top, 20)
            
            Slider(value: $selectedFontSize, in: 12...24, step: 1)
                .padding()
        }
        .padding()
    }
}
